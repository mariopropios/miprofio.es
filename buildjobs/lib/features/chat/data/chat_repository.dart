import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/message.dart';

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
      throw Exception('No puedes enviarte mensajes a ti mismo.');
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

    // 1) Conversaciones donde el usuario es cliente
    final clientConvs = await _client
        .from('conversations')
        .select('*, professionals(name, profile_photo)')
        .eq('user_id', uid)
        .order('updated_at', ascending: false);

    // 2) Profesionales que pertenecen al usuario
    final myProfs = await _client
        .from('professionals')
        .select('id')
        .eq('owner_id', uid);
    final myProfIds = (myProfs as List).map((e) => e['id'] as String).toList();

    List profConvs = [];
    if (myProfIds.isNotEmpty) {
      profConvs = await _client
          .from('conversations')
          .select('*, professionals(name, profile_photo)')
          .inFilter('professional_id', myProfIds)
          .order('updated_at', ascending: false);
    }

    // Combinar y deduplicar por ID
    final seen = <String>{};
    final all = <Conversation>[];
    for (final row in [...clientConvs, ...profConvs]) {
      final conv = Conversation.fromJson(row as Map<String, dynamic>);
      if (seen.add(conv.id)) all.add(conv);
    }
    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all;
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

  /// Número de mensajes no leídos del usuario actual en todas sus conversaciones.
  Future<int> unreadCount() async {
    final uid = _uid;
    if (uid == null) return 0;

    final data = await _client
        .from('messages')
        .select('id')
        .neq('sender_id', uid)
        .isFilter('read_at', null)
        .inFilter(
          'conversation_id',
          (await _client
                  .from('conversations')
                  .select('id')
                  .or('user_id.eq.$uid,professional_id.in.(select id from professionals where owner_id=eq.$uid)'))
              .map((e) => e['id'] as String)
              .toList(),
        );

    return (data as List).length;
  }
}
