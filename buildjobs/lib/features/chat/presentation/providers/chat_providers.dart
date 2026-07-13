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

/// Conversaciones marcadas como leídas en cliente hasta que el servidor confirme.
final locallyReadConversationIdsProvider =
    StateProvider<Set<String>>((ref) => {});

List<Conversation> _applyLocalReadOverrides(
  List<Conversation> list,
  Set<String> locallyRead,
) {
  if (locallyRead.isEmpty) return list;
  return list
      .map(
        (c) => locallyRead.contains(c.id) && c.unreadCount > 0
            ? c.copyWith(unreadCount: 0)
            : c,
      )
      .toList();
}

/// Lista de conversaciones con no-leídos optimistas aplicados (sin flash al volver).
final conversationsListProvider = Provider<AsyncValue<List<Conversation>>>((ref) {
  ref.listen(conversationsProvider, (previous, next) {
    next.whenData((list) {
      final local = ref.read(locallyReadConversationIdsProvider);
      if (local.isEmpty) return;
      final confirmedRead = local.where((id) {
        final conv = list.where((c) => c.id == id).firstOrNull;
        return conv != null && conv.unreadCount == 0;
      }).toSet();
      if (confirmedRead.isNotEmpty) {
        ref.read(locallyReadConversationIdsProvider.notifier).update(
              (s) => s.difference(confirmedRead),
            );
      }
    });
  });

  final base = ref.watch(conversationsProvider);
  final locallyRead = ref.watch(locallyReadConversationIdsProvider);
  return base.whenData((list) => _applyLocalReadOverrides(list, locallyRead));
});

void markConversationReadLocally(Ref ref, String conversationId) {
  ref.read(locallyReadConversationIdsProvider.notifier).update(
        (s) => {...s, conversationId},
      );
}

/// Total de mensajes sin leer (para badge en la barra de navegación).
final totalUnreadMessagesProvider = Provider<int>((ref) {
  final conversations = ref.watch(conversationsListProvider);
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
