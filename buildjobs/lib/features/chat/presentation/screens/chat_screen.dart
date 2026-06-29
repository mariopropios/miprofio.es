import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/message.dart';
import '../../data/chat_repository.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_message_state.dart';

/// Prefijo que distingue mensajes de imagen de texto plano.
const _imagePrefix = '[image]';

// ── Providers ─────────────────────────────────────────────────────────────────

final _chatRepoProvider = chatRepositoryProvider;

final _conversationIdProvider =
    FutureProvider.family<String, String>((ref, professionalId) {
  return ref.read(_chatRepoProvider).getOrCreateConversation(professionalId);
});

// ── Chat state & notifier ─────────────────────────────────────────────────────

class _ChatState {
  const _ChatState({
    this.messages = const [],
    this.isLoading = true,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  _ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) =>
      _ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class _ChatNotifier extends StateNotifier<_ChatState> {
  _ChatNotifier({
    required this.conversationId,
    required this.repo,
    required this.currentUserId,
    this.onMessagesRead,
  }) : super(const _ChatState()) {
    _load();
    _subscribeRealtime();
  }

  final String conversationId;
  final ChatRepository repo;
  final String currentUserId;
  final VoidCallback? onMessagesRead;
  RealtimeChannel? _channel;
  int _tempCounter = 0;

  Future<void> _load() async {
    try {
      final msgs = await repo.getMessages(conversationId);
      if (mounted) {
        state = state.copyWith(messages: msgs, isLoading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  void _subscribeRealtime() {
    _channel = Supabase.instance.client
        .channel('chat_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            if (!mounted) return;
            try {
              final newMsg = ChatMessage.fromJson(payload.newRecord);
              final existing = state.messages;
              final tempIdx = existing.indexWhere(
                (m) =>
                    m.id.startsWith('temp-') &&
                    m.body == newMsg.body &&
                    m.senderId == newMsg.senderId,
              );
              List<ChatMessage> updated;
              if (tempIdx >= 0) {
                updated = [...existing];
                updated[tempIdx] = newMsg;
              } else if (!existing.any((m) => m.id == newMsg.id)) {
                updated = [...existing, newMsg];
              } else {
                return;
              }
              state = state.copyWith(messages: updated);
              if (newMsg.senderId != currentUserId) {
                markAsRead();
              }
            } catch (_) {}
          },
        )
        .subscribe();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final tempId = 'temp-${_tempCounter++}';
    final tempMsg = ChatMessage(
      id: tempId,
      conversationId: conversationId,
      senderId: currentUserId,
      body: trimmed,
      createdAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(messages: [...state.messages, tempMsg]);

    try {
      await repo.sendMessage(conversationId: conversationId, body: trimmed);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted && state.messages.any((m) => m.id == tempId)) {
        final fresh = await repo.getMessages(conversationId);
        if (mounted) state = state.copyWith(messages: fresh);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != tempId).toList(),
          error: e.toString(),
        );
        rethrow;
      }
    }
  }

  Future<void> markAsRead() async {
    await repo.markAsRead(conversationId);
    onMessagesRead?.call();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final _chatNotifierProvider = StateNotifierProvider.autoDispose
    .family<_ChatNotifier, _ChatState, String>(
  (ref, conversationId) {
    final repo = ref.read(_chatRepoProvider);
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? '';
    return _ChatNotifier(
      conversationId: conversationId,
      repo: repo,
      currentUserId: currentUserId,
      onMessagesRead: () => ref.invalidate(conversationsProvider),
    );
  },
);

// ── Screen ────────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerWidget {
  const ChatScreen({
    super.key,
    required this.professionalId,
    required this.professionalName,
    this.professionalPhoto,
    this.conversationId,
  });

  final String professionalId;
  final String professionalName;
  final String? professionalPhoto;
  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openProfile() =>
        context.push(AppRoutes.companyDetailPath(professionalId));

    final appBar = _ChatAppBar(
      name: professionalName,
      photoUrl: professionalPhoto,
      onAvatarTap: openProfile,
    );

    if (conversationId != null) {
      return Scaffold(
        appBar: appBar,
        body: _ChatBody(conversationId: conversationId!),
      );
    }

    final convAsync = ref.watch(_conversationIdProvider(professionalId));
    return Scaffold(
      appBar: appBar,
      body: convAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => ChatErrorState(
          error: e,
          onRetry: () =>
              ref.invalidate(_conversationIdProvider(professionalId)),
        ),
        data: (convId) => _ChatBody(conversationId: convId),
      ),
    );
  }
}

// ── AppBar personalizada estilo WhatsApp ──────────────────────────────────────

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.name,
    this.photoUrl,
    this.onAvatarTap,
  });

  final String name;
  final String? photoUrl;
  final VoidCallback? onAvatarTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black26,
      leadingWidth: 40,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.home);
          }
        },
      ),
      title: InkWell(
        onTap: onAvatarTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            _Avatar(name: name, photoUrl: photoUrl, radius: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Toca para ver el perfil',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ChatBody extends ConsumerStatefulWidget {
  const _ChatBody({required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<_ChatBody> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _showEmojiPanel = false;
  bool _sendingImage = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _markConversationRead();
    });
  }

  Future<void> _markConversationRead() async {
    await ref
        .read(_chatNotifierProvider(widget.conversationId).notifier)
        .markAsRead();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleEmojiPanel() {
    setState(() => _showEmojiPanel = !_showEmojiPanel);
    if (_showEmojiPanel) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
  }

  void _insertEmoji(String emoji) {
    final sel = _controller.selection;
    final text = _controller.text;
    final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final end = sel.isValid ? sel.end.clamp(0, text.length) : text.length;
    final newText = text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _pickAndSendImage() async {
    if (_sendingImage) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file == null) return;

      setState(() => _sendingImage = true);
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';

      final repo = ref.read(_chatRepoProvider);
      final url = await repo.uploadChatImage(bytes, fileName);

      await ref
          .read(_chatNotifierProvider(widget.conversationId).notifier)
          .sendMessage('$_imagePrefix$url');
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  void _onMicTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mensajes de voz disponibles próximamente'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _scrollToBottom();

    try {
      await ref
          .read(_chatNotifierProvider(widget.conversationId).notifier)
          .sendMessage(text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        _controller.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState =
        ref.watch(_chatNotifierProvider(widget.conversationId));
    final currentUserId =
        ref.read(supabaseClientProvider).auth.currentUser?.id ?? '';

    ref.listen(_chatNotifierProvider(widget.conversationId), (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Column(
      children: [
        Expanded(
          child: _buildMessages(chatState, currentUserId),
        ),
        // Indicador de carga al subir imagen
        if (_sendingImage)
          LinearProgressIndicator(
            minHeight: 2,
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
          ),
        // Panel de emojis (encima de la barra de input)
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _showEmojiPanel
              ? _EmojiPanel(onEmojiSelected: _insertEmoji)
              : const SizedBox.shrink(),
        ),
        _InputBar(
          controller: _controller,
          focusNode: _focusNode,
          hasText: _hasText,
          showingEmoji: _showEmojiPanel,
          onSend: _send,
          onToggleEmoji: _toggleEmojiPanel,
          onAttach: _pickAndSendImage,
          onMicTap: _onMicTap,
        ),
      ],
    );
  }

  Widget _buildMessages(_ChatState chatState, String currentUserId) {
    if (chatState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatState.error != null && chatState.messages.isEmpty) {
      return ChatErrorState(
        error: chatState.error!,
        title: 'No se pudieron cargar los mensajes',
        onRetry: () =>
            ref.invalidate(_chatNotifierProvider(widget.conversationId)),
      );
    }

    if (chatState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline,
                size: 16, color: AppTheme.textSecondary),
            const SizedBox(height: 6),
            Text(
              'Los mensajes están cifrados de extremo\na extremo en esta conversación.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      // Fondo ligeramente diferente del AppBar (como WhatsApp)
      color: const Color(0xFF0D1418),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: chatState.messages.length,
        itemBuilder: (context, index) {
          final msg = chatState.messages[index];
          final isMe = msg.senderId == currentUserId;
          final isPending = msg.id.startsWith('temp-');

          final showDate = index == 0 ||
              !_sameDay(
                chatState.messages[index - 1].createdAt,
                msg.createdAt,
              );

          // Agrupar burbujas consecutivas del mismo remitente
          final isFirst = index == 0 ||
              chatState.messages[index - 1].senderId != msg.senderId;
          final isLast = index == chatState.messages.length - 1 ||
              chatState.messages[index + 1].senderId != msg.senderId;

          return Column(
            children: [
              if (showDate) _DateChip(date: msg.createdAt),
              _MessageBubble(
                message: msg,
                isMe: isMe,
                isPending: isPending,
                isFirst: isFirst,
                isLast: isLast,
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Burbuja de mensaje (estilo WhatsApp) ──────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.isPending = false,
    this.isFirst = true,
    this.isLast = true,
  });

  final ChatMessage message;
  final bool isMe;
  final bool isPending;
  final bool isFirst;
  final bool isLast;

  // Colores exactos de WhatsApp Dark
  static const _myBubble = Color(0xFF005C4B);
  static const _theirBubble = Color(0xFF1F2C34);

  bool get _isImage => message.body.startsWith(_imagePrefix);
  String get _imageUrl => message.body.substring(_imagePrefix.length);

  BorderRadius _buildRadius() => BorderRadius.only(
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
        bottomLeft: Radius.circular(isMe ? 8 : (isLast ? 2 : 8)),
        bottomRight: Radius.circular(isMe ? (isLast ? 2 : 8) : 8),
      );

  Widget _timestamp() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 3),
            _TickIcon(isPending: isPending, isRead: message.isRead),
          ],
        ],
      );

  @override
  Widget build(BuildContext context) {
    final radius = _buildRadius();

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 6 : 1,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          decoration: BoxDecoration(
            color: isMe
                ? _myBubble.withValues(alpha: isPending ? 0.65 : 1.0)
                : _theirBubble,
            borderRadius: radius,
          ),
          child: _isImage
              ? _ImageContent(
                  url: _imageUrl,
                  radius: radius,
                  timestamp: _timestamp(),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          message.body,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      _timestamp(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

// ── Icono de ticks (doble azul = leído, doble gris = entregado, reloj = enviando)

class _TickIcon extends StatelessWidget {
  const _TickIcon({required this.isPending, required this.isRead});

  final bool isPending;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    if (isPending) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      );
    }
    // Doble tick azul = leído, doble tick gris = entregado
    final color = isRead
        ? const Color(0xFF53BDEB) // azul WhatsApp
        : Colors.white.withValues(alpha: 0.55);

    return Icon(
      isRead ? Icons.done_all_rounded : Icons.done_all_rounded,
      size: 15,
      color: color,
    );
  }
}

// ── Contenido de imagen en burbuja ────────────────────────────────────────────

class _ImageContent extends StatelessWidget {
  const _ImageContent({
    required this.url,
    required this.radius,
    required this.timestamp,
  });

  final String url;
  final BorderRadius radius;
  final Widget timestamp;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            width: 220,
            placeholder: (_, __) => const SizedBox(
              width: 220,
              height: 160,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => const SizedBox(
              width: 220,
              height: 120,
              child: Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 40),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(6),
              ),
              child: timestamp,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Separador de fecha ────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF182229),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _label(date),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  String _label(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Hoy';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Ayer';
    }
    return '${local.day}/${local.month}/${local.year}';
  }
}

// ── Panel de emojis ───────────────────────────────────────────────────────────

class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.onEmojiSelected});

  final ValueChanged<String> onEmojiSelected;

  static const _emojis = [
    // Caritas
    '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃',
    '😉','😊','😇','🥰','😍','🤩','😘','😗','😚','😙',
    '🥲','😋','😛','😜','🤪','😝','🤑','🤗','🤭','🤫',
    '🤔','🤐','🤨','😐','😑','😶','😏','😒','🙄','😬',
    '🥸','😲','🥺','😢','😭','😤','😠','😡','🤬','🥵',
    // Gestos y manos
    '👍','👎','👏','🙌','🤝','🤜','🤛','✊','👊','🤞',
    '🤟','🤙','👌','🤌','✌️','🖖','👋','🤚','🖐','✋',
    // Corazones y símbolos
    '❤️','🧡','💛','💚','💙','💜','🖤','🤍','💔','❤️‍🔥',
    '💯','💢','💥','💫','⭐','🌟','✨','🎉','🎊','🔥',
    // Objetos y misc
    '😎','🤓','🧐','😴','🤒','🤕','🤠','🥳','🤡','👻',
    '💀','🙈','🙉','🙊','🐶','🐱','🐭','🐹','🐰','🦊',
    '📷','📸','🎵','🎶','🏠','🏡','🔑','💡','📱','💻',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      color: const Color(0xFF111B21),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 10,
          childAspectRatio: 1,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _emojis.length,
        itemBuilder: (context, i) => InkWell(
          onTap: () => onEmojiSelected(_emojis[i]),
          borderRadius: BorderRadius.circular(6),
          child: Center(
            child: Text(
              _emojis[i],
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Barra de input (estilo WhatsApp) ─────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onSend,
    required this.showingEmoji,
    required this.onToggleEmoji,
    required this.onAttach,
    required this.onMicTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onSend;
  final bool showingEmoji;
  final VoidCallback onToggleEmoji;
  final VoidCallback onAttach;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: EdgeInsets.fromLTRB(
        8,
        6,
        8,
        6 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Campo de texto ─────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F2C34),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Emoji toggle
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          showingEmoji
                              ? Icons.keyboard_rounded
                              : Icons.emoji_emotions_outlined,
                          key: ValueKey(showingEmoji),
                          color: showingEmoji
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          size: 22,
                        ),
                      ),
                      onPressed: onToggleEmoji,
                      constraints: const BoxConstraints(
                          minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  // Texto
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => onSend(),
                      onTap: () {
                        // Ocultar panel de emojis al tocar el campo de texto
                        if (showingEmoji) onToggleEmoji();
                      },
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Mensaje',
                        hintStyle: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 15),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 4, vertical: 10),
                      ),
                    ),
                  ),
                  // Adjuntar (si no hay texto)
                  if (!hasText)
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 6),
                      child: IconButton(
                        icon: const Icon(
                          Icons.attach_file_rounded,
                          color: AppTheme.textSecondary,
                          size: 22,
                        ),
                        onPressed: onAttach,
                        tooltip: 'Adjuntar imagen',
                        constraints: const BoxConstraints(
                            minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Botón send / mic ────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: child,
            ),
            child: Material(
              key: ValueKey(hasText),
              color: AppTheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: hasText ? onSend : onMicTap,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: Icon(
                    hasText
                        ? Icons.send_rounded
                        : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.photoUrl, this.radius = 20});

  final String name;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(photoUrl!),
        backgroundColor: AppTheme.surfaceElevated,
      );
    }
    final colors = [
      const Color(0xFF1A7F64),
      const Color(0xFF0063CB),
      const Color(0xFF8B4E96),
      const Color(0xFFD14343),
      const Color(0xFFE07B39),
    ];
    final color = colors[name.codeUnitAt(0) % colors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}
