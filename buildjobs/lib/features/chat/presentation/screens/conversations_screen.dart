import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/message.dart';
import '../models/active_chat_route.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_message_state.dart';
import 'chat_screen.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin,
        SingleTickerProviderStateMixin {
  static const _chatSlideDuration = Duration(milliseconds: 280);

  late final AnimationController _chatSlideController;
  late final Animation<Offset> _chatSlideAnimation;

  ActiveChatRoute? _visibleChat;
  GoRouterDelegate? _routerDelegate;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _chatSlideController = AnimationController(
      vsync: this,
      duration: _chatSlideDuration,
      reverseDuration: _chatSlideDuration,
    );
    _chatSlideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _chatSlideController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    ));

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cached = ref.read(conversationsProvider);
      if (!cached.hasValue) {
        ref.invalidate(conversationsProvider);
      }
      _syncNotificationsIfAlreadyGranted();
      _attachRouteListener();
      _syncChatFromRoute();
    });
  }

  void _attachRouteListener() {
    final delegate = GoRouter.of(context).routerDelegate;
    if (_routerDelegate == delegate) return;
    _routerDelegate?.removeListener(_syncChatFromRoute);
    _routerDelegate = delegate;
    _routerDelegate!.addListener(_syncChatFromRoute);
  }

  void _syncChatFromRoute() {
    if (!mounted) return;
    final state = GoRouter.of(context).state;
    final nextChat = ActiveChatRoute.fromRouterState(state);
    final currentId = _visibleChat?.professionalId;
    final nextId = nextChat?.professionalId;

    if (currentId == nextId) {
      if (nextChat != null) {
        _visibleChat = nextChat;
      }
      return;
    }

    if (nextChat != null) {
      setState(() => _visibleChat = nextChat);
      _chatSlideController.forward();
      return;
    }

    if (_visibleChat != null) {
      _chatSlideController.reverse().then((_) {
        if (!mounted) return;
        final stillClosed =
            ActiveChatRoute.fromRouterState(GoRouter.of(context).state) == null;
        if (stillClosed) {
          setState(() => _visibleChat = null);
        }
      });
    }
  }

  /// Solo sincroniza token si el permiso ya estaba concedido; no muestra diálogo.
  Future<void> _syncNotificationsIfAlreadyGranted() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    await NotificationService.syncIfAlreadyAuthorized();
  }

  @override
  void dispose() {
    _routerDelegate?.removeListener(_syncChatFromRoute);
    _chatSlideController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachRouteListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(conversationsProvider);
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
        appBar: _buildAppBar(context),
        body: Center(
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
      );
    }

    final convAsync = ref.watch(conversationsProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          primary: false,
          backgroundColor: AppTheme.scaffoldBackground,
          appBar: _buildAppBar(context),
          body: RepaintBoundary(
            child: Column(
              children: [
                Expanded(
                  child: convAsync.when(
                    skipLoadingOnReload: true,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ChatErrorState(
                      error: e,
                      title: 'No se pudieron cargar los mensajes',
                      onRetry: () => ref.invalidate(conversationsProvider),
                    ),
                    data: (conversations) {
                      if (conversations.isEmpty) {
                        return const _EmptyState();
                      }
                      return RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () async =>
                            ref.invalidate(conversationsProvider),
                        child: ListView.separated(
                          itemCount: conversations.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            indent: 78,
                            color: AppTheme.divider,
                          ),
                          itemBuilder: (context, index) {
                            return RepaintBoundary(
                              child: _ConversationTile(
                                conversation: conversations[index],
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
        ),
        if (_visibleChat != null)
          SlideTransition(
            position: _chatSlideAnimation,
            child: Material(
              color: AppTheme.scaffoldBackground,
              child: ChatScreen(
                professionalId: _visibleChat!.professionalId,
                professionalName: _visibleChat!.name ?? 'Profesional',
                professionalPhoto: _visibleChat!.photo,
                conversationId: _visibleChat!.conversationId,
                peerUserId: _visibleChat!.peerUserId,
                viewingAsProfessional: _visibleChat!.viewingAsProfessional,
              ),
            ),
          ),
      ],
    );
  }

  AppBar _buildAppBar(BuildContext context) {
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
        IconButton(
          onPressed: () => ref.invalidate(conversationsProvider),
          icon: const Icon(Icons.refresh_rounded,
              color: AppTheme.textSecondary, size: 22),
          tooltip: 'Actualizar',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Estado vacío ───────────────────────────────────────────────────────────────

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

// ── Tile de conversación (estilo WhatsApp) ─────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.hasUnread;
    final time = conversation.lastMessageAt != null
        ? _formatDate(conversation.lastMessageAt!)
        : '';
    final raw = conversation.lastMessage;
    final isImage = raw != null && raw.startsWith('[image]');
    final isAudio = raw != null && raw.startsWith('[audio]');
    final preview = isImage
        ? 'Imagen'
        : isAudio
            ? 'Audio'
            : raw ?? 'Conversación iniciada';

    return InkWell(
      onTap: () => context.push(
        AppRoutes.chatPath(conversation.professionalId),
        extra: {
          'name': conversation.peerName,
          'photo': conversation.peerPhoto,
          'conversationId': conversation.id,
          'peerUserId': conversation.userId,
          'viewingAsProfessional': conversation.viewingAsProfessional,
        },
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(
              name: conversation.peerName,
              photoUrl: conversation.peerPhoto,
              radius: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.peerName,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: TextStyle(
                            color: hasUnread
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isImage) ...[
                        Icon(
                          Icons.photo_camera_outlined,
                          size: 14,
                          color: hasUnread
                              ? AppTheme.textPrimary.withValues(alpha: 0.85)
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (isAudio) ...[
                        Icon(
                          Icons.mic_rounded,
                          size: 14,
                          color: hasUnread
                              ? AppTheme.textPrimary.withValues(alpha: 0.85)
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread
                                ? AppTheme.textPrimary.withValues(alpha: 0.9)
                                : AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.w400,
                            fontStyle: raw == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: conversation.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(local.year, local.month, local.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    if (diff == 1) return 'Ayer';
    if (diff < 7) {
      const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return days[(local.weekday - 1) % 7];
    }
    return '${local.day}/${local.month}/${local.year % 100}';
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    this.photoUrl,
    this.radius = 24,
  });

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      final cacheWidth =
          (diameter * MediaQuery.devicePixelRatioOf(context)).ceil();
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: diameter,
          height: diameter,
          fit: BoxFit.cover,
          memCacheWidth: cacheWidth,
          maxWidthDiskCache: cacheWidth,
          fadeInDuration: const Duration(milliseconds: 120),
          placeholder: (_, __) => CircleAvatar(
            radius: radius,
            backgroundColor: AppTheme.surfaceElevated,
          ),
          errorWidget: (_, __, ___) => _initialsAvatar(),
        ),
      );
    }
    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    final colors = [
      const Color(0xFF1A7F64),
      const Color(0xFF0063CB),
      const Color(0xFF8B4E96),
      const Color(0xFFD14343),
      const Color(0xFFE07B39),
      const Color(0xFF2D8A72),
    ];
    final color = colors[name.codeUnitAt(0) % colors.length];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}
