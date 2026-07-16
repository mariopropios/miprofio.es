import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/message.dart';
import '../providers/chat_providers.dart';
import '../../../../shared/widgets/pwa_home_guide_dialog.dart';
import '../widgets/chat_message_state.dart';
import '../widgets/conversation_list_tile.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  bool _refreshing = false;
  bool _showHomeGuide = false;
  final Set<String> _removingIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cached = ref.read(conversationsProvider);
      if (!cached.hasValue) {
        ref.invalidate(conversationsProvider);
      }
      _syncNotificationsIfAlreadyGranted();
    });
  }

  Future<void> _syncNotificationsIfAlreadyGranted() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await NotificationService.syncIfAlreadyAuthorized();
  }

  Future<void> _refreshConversations() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      invalidateConversationLists(ref);
      await Future.wait([
        ref.read(conversationsProvider.future),
        ref.read(archivedConversationsProvider.future),
      ]);
    } catch (_) {
      // El error se refleja en conversationsListProvider.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _openHomeGuide() {
    setState(() => _showHomeGuide = true);
  }

  void _closeHomeGuide() {
    setState(() => _showHomeGuide = false);
  }

  void _openArchived() {
    context.push(AppRoutes.archivedMessages);
  }

  Future<void> _archive(Conversation conversation) async {
    setState(() => _removingIds.add(conversation.id));
    try {
      await ref.read(chatRepositoryProvider).setConversationArchived(
            conversationId: conversation.id,
            archived: true,
          );
      invalidateConversationLists(ref);
      if (!mounted) return;
      setState(() => _removingIds.remove(conversation.id));
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chat archivado'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              try {
                await ref.read(chatRepositoryProvider).setConversationArchived(
                      conversationId: conversation.id,
                      archived: false,
                    );
                invalidateConversationLists(ref);
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _removingIds.remove(conversation.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo archivar: $e')),
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      invalidateConversationLists(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(conversationsRealtimeProvider);

    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        primary: false,
        appBar: _buildAppBar(showArchive: false),
        body: Column(
          children: [
            if (_showHomeGuide) PwaHomeGuidePanel(onClose: _closeHomeGuide),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 64, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      const Text(
                        'Inicia sesión para ver tus mensajes',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => context.go(AppRoutes.profile),
                        child: const Text('Iniciar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final convAsync = ref.watch(conversationsListProvider);
    final archivedAsync = ref.watch(archivedConversationsListProvider);
    final archivedCount = archivedAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );
    final archivedUnread = archivedAsync.maybeWhen(
      data: (list) => list.fold<int>(0, (s, c) => s + c.unreadCount),
      orElse: () => 0,
    );

    return Scaffold(
      primary: false,
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: _buildAppBar(showArchive: true),
      body: RepaintBoundary(
        child: Column(
          children: [
            if (_showHomeGuide) PwaHomeGuidePanel(onClose: _closeHomeGuide),
            Expanded(
              child: convAsync.when(
                skipLoadingOnReload: true,
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ChatErrorState(
                  error: e,
                  title: 'No se pudieron cargar los mensajes',
                  onRetry: () => invalidateConversationLists(ref),
                ),
                data: (conversations) {
                  final visible = conversations
                      .where((c) => !_removingIds.contains(c.id))
                      .toList();
                  final showArchivedRow = archivedCount > 0;
                  if (visible.isEmpty && !showArchivedRow) {
                    return const _EmptyState();
                  }
                  return RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: _refreshConversations,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: visible.length + (showArchivedRow ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 78,
                        color: AppTheme.divider,
                      ),
                      itemBuilder: (context, index) {
                        if (showArchivedRow && index == visible.length) {
                          return _ArchivedEntryRow(
                            count: archivedCount,
                            unread: archivedUnread,
                            onTap: _openArchived,
                          );
                        }
                        final conversation = visible[index];
                        return AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: ConversationListTile(
                            key: ValueKey(conversation.id),
                            conversation: conversation,
                            onOpen: () => _openChat(conversation),
                            onArchive: () => _archive(conversation),
                            onDelete: () => _delete(conversation),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar({required bool showArchive}) {
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black26,
      title: const Text(
        'Mensajes',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      actions: [
        if (showArchive)
          IconButton(
            onPressed: _openArchived,
            icon: const Icon(Icons.archive_outlined,
                color: AppTheme.textSecondary, size: 22),
            tooltip: 'Archivados',
          ),
        if (kIsWeb)
          IconButton(
            onPressed: _openHomeGuide,
            icon: const Icon(Icons.notifications_outlined,
                color: AppTheme.textSecondary, size: 22),
            tooltip: 'Añadir a pantalla de inicio',
          ),
        IconButton(
          onPressed: _refreshing ? null : _refreshConversations,
          icon: _refreshing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.textSecondary,
                  ),
                )
              : const Icon(Icons.refresh_rounded,
                  color: AppTheme.textSecondary, size: 22),
          tooltip: 'Actualizar',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _ArchivedEntryRow extends StatelessWidget {
  const _ArchivedEntryRow({
    required this.count,
    required this.unread,
    required this.onTap,
  });

  final int count;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppTheme.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.archive_outlined,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Archivados',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              ConversationUnreadBadge(count: unread),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Sin conversaciones',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Encuentra un profesional y\nenvíale un mensaje.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
