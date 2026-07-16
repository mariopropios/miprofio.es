import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/message.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_message_state.dart';
import '../widgets/conversation_list_tile.dart';

class ArchivedConversationsScreen extends ConsumerStatefulWidget {
  const ArchivedConversationsScreen({super.key});

  @override
  ConsumerState<ArchivedConversationsScreen> createState() =>
      _ArchivedConversationsScreenState();
}

class _ArchivedConversationsScreenState
    extends ConsumerState<ArchivedConversationsScreen> {
  final Set<String> _removingIds = {};

  Future<void> _refresh() async {
    ref.invalidate(archivedConversationsProvider);
    await ref.read(archivedConversationsProvider.future);
  }

  Future<void> _unarchive(Conversation conversation) async {
    setState(() => _removingIds.add(conversation.id));
    try {
      await ref.read(chatRepositoryProvider).setConversationArchived(
            conversationId: conversation.id,
            archived: false,
          );
      invalidateConversationLists(ref);
      if (!mounted) return;
      setState(() => _removingIds.remove(conversation.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat desarchivado'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _removingIds.remove(conversation.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo desarchivar: $e')),
        );
      }
    }
  }

  Future<void> _delete(Conversation conversation) async {
    final ok = await confirmDeleteConversation(
      context,
      peerName: conversation.peerName,
    );
    if (!ok || !mounted) return;

    setState(() => _removingIds.add(conversation.id));
    try {
      await ref
          .read(chatRepositoryProvider)
          .hideConversation(conversation.id);
      invalidateConversationLists(ref);
      if (!mounted) return;
      setState(() => _removingIds.remove(conversation.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat eliminado'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _removingIds.remove(conversation.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: $e')),
        );
      }
    }
  }

  void _openChat(Conversation conversation) {
    ref.read(locallyReadConversationIdsProvider.notifier).update(
          (s) => {...s, conversation.id},
        );
    context.push(
      AppRoutes.chatPathWith(
        professionalId: conversation.professionalId,
        conversationId: conversation.id,
        name: conversation.peerName,
        photo: conversation.peerPhoto,
        peerUserId: conversation.userId,
        viewingAsProfessional: conversation.viewingAsProfessional,
      ),
      extra: {
        'name': conversation.peerName,
        'photo': conversation.peerPhoto,
        'conversationId': conversation.id,
        'peerUserId': conversation.userId,
        'viewingAsProfessional': conversation.viewingAsProfessional,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(conversationsRealtimeProvider);
    final async = ref.watch(archivedConversationsListProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Archivados',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: async.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ChatErrorState(
          error: e,
          title: 'No se pudieron cargar los archivados',
          onRetry: () => ref.invalidate(archivedConversationsProvider),
        ),
        data: (conversations) {
          final visible =
              conversations.where((c) => !_removingIds.contains(c.id)).toList();
          if (visible.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No hay chats archivados',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 78,
                color: AppTheme.divider,
              ),
              itemBuilder: (context, index) {
                final conversation = visible[index];
                return AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: ConversationListTile(
                    key: ValueKey(conversation.id),
                    conversation: conversation,
                    archiveLabel: 'Desarchivar',
                    onOpen: () => _openChat(conversation),
                    onArchive: () => _unarchive(conversation),
                    onDelete: () => _delete(conversation),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
