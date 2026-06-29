import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/message.dart';
import 'chat_exceptions.dart';

class ChatRepository {
  ChatRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  // ── Conversaciones ──────────────────────────────────────────────────────────

  /// Obtiene o crea la conversación entre el usuario actual y un profesional.
  Future<String> getOrCreateConversation(String professionalId) async {
    final uid = _uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    // Verificar que el usuario no es el dueño del perfil profesional
    final profOwner = await _client
        .from('professionals')
        .select('owner_id')
        .eq('id', professionalId)
        .maybeSingle();
    if (profOwner != null && profOwner['owner_id'] == uid) {
      throw const ChatSelfMessageException();
    }

    // Intentar obtener la conversación existente
    final existing = await _client
        .from('conversations')
        .select('id')
        .eq('user_id', uid)
        .eq('professional_id', professionalId)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    // Crear nueva conversación
    final created = await _client
        .from('conversations')
        .insert({'user_id': uid, 'professional_id': professionalId})
        .select('id')
        .single();

    return created['id'] as String;
  }

  /// Lista de conversaciones del usuario actual (como cliente o como profesional).
  Future<List<Conversation>> getConversations() async {
    final uid = _uid;
    if (uid == null) return [];

    const select =
        '*, professionals(name, profile_photo), client:profiles!user_id(full_name, avatar_url)';

    // 1) Conversaciones donde el usuario es cliente
    final clientConvs = await _client
        .from('conversations')
        .select(select)
        .eq('user_id', uid)
        .order('updated_at', ascending: false);

    // 2) Profesionales que pertenecen al usuario
    final myProfs = await _client
        .from('professionals')
        .select('id')
        .eq('owner_id', uid);
    final ownedProfessionalIds =
        (myProfs as List).map((e) => e['id'] as String).toSet();

    List profConvs = [];
    if (ownedProfessionalIds.isNotEmpty) {
      profConvs = await _client
          .from('conversations')
          .select(select)
          .inFilter('professional_id', ownedProfessionalIds.toList())
          .order('updated_at', ascending: false);
    }

    // Combinar y deduplicar por ID
    final seen = <String>{};
    final rows = <Map<String, dynamic>>[];
    for (final row in [...clientConvs, ...profConvs]) {
      final map = row as Map<String, dynamic>;
      if (seen.add(map['id'] as String)) rows.add(map);
    }

    if (rows.isEmpty) return [];

    final convIds = rows.map((r) => r['id'] as String).toList();
    final unreadByConversation = await _unreadCountsForConversations(
      conversationIds: convIds,
      currentUserId: uid,
    );

    final all = rows
        .map(
          (row) => Conversation.fromRow(
            row,
            currentUserId: uid,
            ownedProfessionalIds: ownedProfessionalIds,
            unreadCount: unreadByConversation[row['id'] as String] ?? 0,
          ),
        )
        .toList();
    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all;
  }

  Future<Map<String, int>> _unreadCountsForConversations({
    required List<String> conversationIds,
    required String currentUserId,
  }) async {
    if (conversationIds.isEmpty) return {};

    final data = await _client
        .from('messages')
        .select('conversation_id')
        .inFilter('conversation_id', conversationIds)
        .neq('sender_id', currentUserId)
        .isFilter('read_at', null);

    final counts = <String, int>{};
    for (final row in data as List) {
      final id = row['conversation_id'] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  // ── Mensajes ────────────────────────────────────────────────────────────────

  /// Obtiene todos los mensajes de una conversación (fetch directo, sin stream).
  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final data = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return (data as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  /// Stream de mensajes en tiempo real para una conversación.
  Stream<List<ChatMessage>> messagesStream(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map(ChatMessage.fromJson).toList());
  }

  /// Enviar un mensaje e invalidar la conversación (updated_at).
  Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Usuario no autenticado');

    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'body': body.trim(),
    });

    // ── Push notification al destinatario ─────────────────────────────────
    // Se lanza en background; si falla no afecta al envío del mensaje.
    _sendPushNotification(
      conversationId: conversationId,
      senderId: uid,
      body: body.trim(),
    );
  }

  Future<void> _sendPushNotification({
    required String conversationId,
    required String senderId,
    required String body,
  }) async {
    try {
      // Nombre del remitente para el título de la notificación
      final profileRow = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', senderId)
          .maybeSingle();
      final senderName = profileRow?['full_name'] as String? ?? 'Nuevo mensaje';

      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'conversation_id': conversationId,
          'sender_id': senderId,
          'sender_name': senderName,
          'body': body,
        },
      );
    } catch (e) {
      debugPrint('[Push] Error enviando notificación: $e');
    }
  }

  /// Marcar mensajes de la otra parte como leídos.
  Future<void> markAsRead(String conversationId) async {
    final uid = _uid;
    if (uid == null) return;

    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', uid)
        .isFilter('read_at', null);
  }

  // ── Imágenes ─────────────────────────────────────────────────────────────────

  /// Sube una imagen al bucket `chat-images` y devuelve la URL pública.
  Future<String> uploadChatImage(Uint8List bytes, String fileName) async {
    const bucket = 'chat-images';
    final path =
        '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Número de mensajes no leídos del usuario actual en todas sus conversaciones.
  Future<int> unreadCount() async {
    final conversations = await getConversations();
    return conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
  }
}
