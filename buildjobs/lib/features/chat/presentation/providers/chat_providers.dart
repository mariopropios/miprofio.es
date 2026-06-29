import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/models/message.dart';
import '../../data/chat_repository.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  ref.watch(currentUserProvider);
  return ref.read(chatRepositoryProvider).getConversations();
});

/// Total de mensajes sin leer (para badge en la barra de navegación).
final totalUnreadMessagesProvider = Provider<int>((ref) {
  final conversations = ref.watch(conversationsProvider);
  return conversations.maybeWhen(
    data: (list) => list.fold<int>(0, (sum, c) => sum + c.unreadCount),
    orElse: () => 0,
  );
});

/// Suscripción Realtime que mantiene la lista de conversaciones al día.
final conversationsRealtimeProvider = Provider<void>((ref) {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;

  final channel = Supabase.instance.client
      .channel('conversations_list_$uid')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (_) => ref.invalidate(conversationsProvider),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        callback: (_) => ref.invalidate(conversationsProvider),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'conversations',
        callback: (_) => ref.invalidate(conversationsProvider),
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
  });
});
