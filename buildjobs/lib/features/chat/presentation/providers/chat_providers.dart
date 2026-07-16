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

final archivedConversationsProvider =
    FutureProvider<List<Conversation>>((ref) {
  ref.watch(currentUserProvider);
  return ref.read(chatRepositoryProvider).getConversations(
        filter: ConversationListFilter.archived,
      );
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

void _pruneConfirmedLocalReads(
  Ref ref,
  AsyncValue<List<Conversation>> next,
) {
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
}

/// Lista principal con no-leídos optimistas aplicados.
final conversationsListProvider =
    Provider<AsyncValue<List<Conversation>>>((ref) {
  ref.listen(conversationsProvider, (previous, next) {
    _pruneConfirmedLocalReads(ref, next);
  });

  final base = ref.watch(conversationsProvider);
  final locallyRead = ref.watch(locallyReadConversationIdsProvider);
  return base.whenData((list) => _applyLocalReadOverrides(list, locallyRead));
});

/// Lista de archivados con no-leídos optimistas.
final archivedConversationsListProvider =
    Provider<AsyncValue<List<Conversation>>>((ref) {
  ref.listen(archivedConversationsProvider, (previous, next) {
    _pruneConfirmedLocalReads(ref, next);
  });

  final base = ref.watch(archivedConversationsProvider);
  final locallyRead = ref.watch(locallyReadConversationIdsProvider);
  return base.whenData((list) => _applyLocalReadOverrides(list, locallyRead));
});

void markConversationReadLocally(Ref ref, String conversationId) {
  ref.read(locallyReadConversationIdsProvider.notifier).update(
        (s) => {...s, conversationId},
      );
}

void invalidateConversationLists(WidgetRef ref) {
  ref.invalidate(conversationsProvider);
  ref.invalidate(archivedConversationsProvider);
}

/// Total de mensajes sin leer (lista principal + archivados) para badge nav.
final totalUnreadMessagesProvider = Provider<int>((ref) {
  final active = ref.watch(conversationsListProvider);
  final archived = ref.watch(archivedConversationsListProvider);
  final activeCount = active.maybeWhen(
    data: (list) => list.fold<int>(0, (sum, c) => sum + c.unreadCount),
    orElse: () => 0,
  );
  final archivedCount = archived.maybeWhen(
    data: (list) => list.fold<int>(0, (sum, c) => sum + c.unreadCount),
    orElse: () => 0,
  );
  return activeCount + archivedCount;
});

/// Suscripción Realtime que mantiene la lista de conversaciones al día.
final conversationsRealtimeProvider = Provider<void>((ref) {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return;

  void refresh() {
    ref.invalidate(conversationsProvider);
    ref.invalidate(archivedConversationsProvider);
  }

  final channel = Supabase.instance.client
      .channel('conversations_list_$uid')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (_) => refresh(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'messages',
        callback: (_) => refresh(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'conversations',
        callback: (_) => refresh(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversation_user_state',
        callback: (_) => refresh(),
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
  });
});
