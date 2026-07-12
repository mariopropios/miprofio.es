import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/chat_attachment_picker.dart';
import '../../../../core/services/chat_audio_recorder.dart';
import '../../../../core/services/mic_permission_helper.dart';
import '../../../../core/services/push_notification_clear.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/message.dart';
import '../../data/chat_repository.dart';
import '../providers/chat_providers.dart';
import '../../../../core/utils/x_file_bytes_reader.dart';
import '../widgets/chat_attachment_menu.dart';
import '../widgets/chat_message_state.dart';

/// Prefijo que distingue mensajes de imagen de texto plano.
const _imagePrefix = '[image]';

/// Prefijo que distingue mensajes de audio de texto plano.
const _audioPrefix = '[audio]';

String _imageContentType(String ext, String? mimeType) {
  if (mimeType != null && mimeType.startsWith('image/')) return mimeType;
  switch (ext.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';
    default:
      return 'image/jpeg';
  }
}

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
    this.unreadDividerMessageId,
    this.unreadCountAtOpen = 0,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  /// Primer mensaje no leído al abrir el chat (se mantiene toda la sesión).
  final String? unreadDividerMessageId;
  final int unreadCountAtOpen;

  _ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    String? unreadDividerMessageId,
    int? unreadCountAtOpen,
  }) =>
      _ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        unreadDividerMessageId:
            unreadDividerMessageId ?? this.unreadDividerMessageId,
        unreadCountAtOpen: unreadCountAtOpen ?? this.unreadCountAtOpen,
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

      String? dividerId;
      var unreadCount = 0;
      for (final m in msgs) {
        if (m.senderId != currentUserId && !m.isRead) {
          dividerId ??= m.id;
          unreadCount++;
        }
      }

      if (mounted) {
        state = state.copyWith(
          messages: msgs,
          isLoading: false,
          unreadDividerMessageId: dividerId,
          unreadCountAtOpen: unreadCount,
        );
      }

      await markAsRead();
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  void _applyMessageUpdate(Map<String, dynamic> record) {
    final updated = ChatMessage.fromJson(record);
    final existing = state.messages;
    final idx = existing.indexWhere((m) => m.id == updated.id);
    if (idx < 0) return;
    final newList = [...existing];
    newList[idx] = updated;
    state = state.copyWith(messages: newList);
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
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
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
              _applyMessageUpdate(payload.newRecord);
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
    onMessagesRead?.call();
    await clearGroupedChatNotifications(conversationId);
    await repo.markAsRead(conversationId);
  }

  /// Recarga mensajes y recalcula no leídos cada vez que se abre el chat.
  Future<void> prepareForOpen() async {
    try {
      final msgs = await repo.getMessages(conversationId);

      String? dividerId;
      var unreadCount = 0;
      for (final m in msgs) {
        if (m.senderId != currentUserId && !m.isRead) {
          dividerId ??= m.id;
          unreadCount++;
        }
      }

      if (mounted) {
        state = state.copyWith(
          messages: msgs,
          isLoading: false,
          error: null,
          unreadDividerMessageId: dividerId,
          unreadCountAtOpen: unreadCount,
        );
      }

      await markAsRead();
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
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
    this.peerUserId,
    this.viewingAsProfessional = false,
  });

  final String professionalId;
  final String professionalName;
  final String? professionalPhoto;
  final String? conversationId;
  /// Id del cliente cuando el profesional abre el chat desde Mensajes.
  final String? peerUserId;
  final bool viewingAsProfessional;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openProfile() {
      if (viewingAsProfessional && peerUserId != null) {
        context.push(AppRoutes.userProfilePath(peerUserId!));
        return;
      }
      context.push(AppRoutes.companyDetailPath(professionalId));
    }

    final appBar = _ChatAppBar(
      name: professionalName,
      photoUrl: professionalPhoto,
      onAvatarTap: openProfile,
    );

    if (conversationId != null) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppTheme.scaffoldBackground,
        appBar: appBar,
        body: _ChatBody(conversationId: conversationId!),
      );
    }

    final convAsync = ref.watch(_conversationIdProvider(professionalId));
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.scaffoldBackground,
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

class _ChatBodyState extends ConsumerState<_ChatBody>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _unreadAnchorKey = GlobalKey();
  final _audioRecorder = ChatAudioRecorder();
  bool _hasText = false;
  bool _showEmojiPanel = false;
  bool _sendingImage = false;
  bool _isRecording = false;
  bool _sendingAudio = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  bool _didInitialScroll = false;
  bool _isFirstActivation = true;
  int _openScrollGeneration = 0;
  double _lastViewInsetBottom = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    _focusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markConversationRead();
      _onChatOpened();
    });
  }

  @override
  void activate() {
    super.activate();
    if (_isFirstActivation) {
      _isFirstActivation = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChatOpened());
  }

  Future<void> _onChatOpened() async {
    _openScrollGeneration++;
    final generation = _openScrollGeneration;
    _didInitialScroll = false;

    await clearGroupedChatNotifications(widget.conversationId);

    await ref
        .read(_chatNotifierProvider(widget.conversationId).notifier)
        .prepareForOpen();

    if (!mounted || generation != _openScrollGeneration) return;
    _requestOpenScroll();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      if (_showEmojiPanel) setState(() => _showEmojiPanel = false);
      _scheduleScrollToBottom();
    }
  }

  void _scheduleScrollToBottom() {
    _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _scrollToBottom();
    });
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _scrollToBottom();
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset != _lastViewInsetBottom) {
      _lastViewInsetBottom = inset;
      if (inset > 0 || _focusNode.hasFocus || _showEmojiPanel) {
        _scheduleScrollToBottom();
      }
    }
  }

  void _requestOpenScroll() {
    _attemptOpenScroll(0);
  }

  void _attemptOpenScroll(int attempt) {
    if (!mounted || _didInitialScroll || attempt > 8) return;

    final state = ref.read(_chatNotifierProvider(widget.conversationId));
    if (state.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _attemptOpenScroll(attempt + 1);
      });
      return;
    }

    if (state.messages.isEmpty) {
      _didInitialScroll = true;
      return;
    }

    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _attemptOpenScroll(attempt + 1);
      });
      return;
    }

    _didInitialScroll = true;
    _scrollToInitialPosition(state);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markConversationRead();
    }
  }

  Future<void> _markConversationRead() async {
    await ref
        .read(_chatNotifierProvider(widget.conversationId).notifier)
        .markAsRead();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChanged);
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    clearGroupedChatNotifications(widget.conversationId);
    super.dispose();
  }

  void _scrollToBottom() {
    _scrollToMaxExtent(animated: true);
  }

  void _scrollToMaxExtent({required bool animated}) {
    void apply() {
      if (!_scrollController.hasClients) return;
      const target = 0.0;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        apply();
        WidgetsBinding.instance.addPostFrameCallback((_) => apply());
      });
    });
  }

  void _scrollToInitialPosition(_ChatState chatState) {
    final hasUnread = chatState.unreadDividerMessageId != null &&
        chatState.unreadCountAtOpen > 0;

    if (hasUnread) {
      _scrollToUnreadAnchor();
      return;
    }
    _scrollToMaxExtent(animated: false);
  }

  void _scrollToUnreadAnchor() {
    void apply() {
      final anchorContext = _unreadAnchorKey.currentContext;
      if (anchorContext != null) {
        Scrollable.ensureVisible(
          anchorContext,
          alignment: 0.05,
          duration: Duration.zero,
        );
        return;
      }
      _scrollToMaxExtent(animated: false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        apply();
        WidgetsBinding.instance.addPostFrameCallback((_) => apply());
      });
    });
  }

  void _toggleEmojiPanel() {
    final next = !_showEmojiPanel;
    setState(() => _showEmojiPanel = next);
    if (next) {
      _focusNode.unfocus();
      _scheduleScrollToBottom();
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

  Future<void> _onAttachTap() async {
    if (_sendingImage) return;

    final file = await ChatAttachmentMenu.show(
      context,
      onPick: ChatAttachmentPicker.pick,
    );
    if (file == null || !mounted) return;

    try {
      setState(() => _sendingImage = true);
      final bytes = await readXFileBytes(file);
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo leer la imagen seleccionada')),
          );
        }
        return;
      }
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';

      final repo = ref.read(_chatRepoProvider);
      final url = await repo.uploadChatImage(
        bytes,
        fileName,
        contentType: _imageContentType(ext, file.mimeType),
      );

      await ref
          .read(_chatNotifierProvider(widget.conversationId).notifier)
          .sendMessage('$_imagePrefix$url');
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('Bucket not found')
            ? 'El almacenamiento de imágenes no está configurado. Contacta con soporte.'
            : 'Error al enviar imagen: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  Future<bool> _ensureMicPermission() async {
    if (await _audioRecorder.hasPermission(request: false)) return true;
    if (!mounted) return false;

    // Android/iOS web: pedir en el gesto del tap del micrófono.
    var granted = await _audioRecorder.requestPermission();
    if (granted) return true;
    if (!mounted) return false;

    final proceed = await MicPermissionHelper.showPermissionRationale(context);
    if (!proceed || !mounted) return false;

    granted = await _audioRecorder.requestPermission();
    if (!granted && mounted) {
      await MicPermissionHelper.showBlockedGuide(context);
    }
    return granted;
  }

  Future<void> _startRecording() async {
    try {
      if (_showEmojiPanel) _toggleEmojiPanel();
      _focusNode.unfocus();
      await _audioRecorder.start();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingSeconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar la grabación: $e')),
        );
      }
    }
  }

  Future<void> _onMicTap() async {
    if (_isRecording || _sendingAudio) return;
    final granted = await _ensureMicPermission();
    if (!granted || !mounted) return;
    await _startRecording();
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _audioRecorder.cancel();
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _stopAndSendAudio() async {
    if (_sendingAudio) return;
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _sendingAudio = true;
    });

    try {
      final recorded = await _audioRecorder.stop();
      if (recorded == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grabación demasiado corta')),
          );
        }
        return;
      }

      final repo = ref.read(_chatRepoProvider);
      final url = await repo.uploadChatAudio(
        Uint8List.fromList(recorded.bytes),
        recorded.fileName,
        contentType: recorded.contentType,
      );

      await ref
          .read(_chatNotifierProvider(widget.conversationId).notifier)
          .sendMessage('$_audioPrefix$url|${recorded.durationSec}');
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar audio: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingAudio = false);
    }
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
      if (!_didInitialScroll && !next.isLoading && next.messages.isNotEmpty) {
        _didInitialScroll = true;
        _scrollToInitialPosition(next);
      }
      if (_didInitialScroll &&
          (prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Column(
      children: [
        Expanded(
          child: _buildMessages(chatState, currentUserId),
        ),
        // Indicador de carga al subir imagen
        if (_sendingImage || _sendingAudio)
          LinearProgressIndicator(
            minHeight: 2,
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
          ),
        // Panel de emojis (encima de la barra de input)
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _showEmojiPanel && !_isRecording
              ? _EmojiPanel(onEmojiSelected: _insertEmoji)
              : const SizedBox.shrink(),
        ),
        if (_isRecording)
          _RecordingBar(
            seconds: _recordingSeconds,
            onCancel: _cancelRecording,
            onSend: _stopAndSendAudio,
          )
        else
          _InputBar(
            controller: _controller,
            focusNode: _focusNode,
            hasText: _hasText,
            showingEmoji: _showEmojiPanel,
            onSend: _send,
            onToggleEmoji: _toggleEmojiPanel,
            onAttach: _onAttachTap,
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
        reverse: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: chatState.messages.length,
        itemBuilder: (context, index) {
          final reverseIndex = chatState.messages.length - 1 - index;
          final msg = chatState.messages[reverseIndex];
          final isMe = msg.senderId == currentUserId;
          final isPending = msg.id.startsWith('temp-');

          final showUnreadDivider =
              chatState.unreadDividerMessageId == msg.id &&
                  chatState.unreadCountAtOpen > 0;

          final showDate = reverseIndex == 0 ||
              !_sameDay(
                chatState.messages[reverseIndex - 1].createdAt,
                msg.createdAt,
              );

          final isFirst = reverseIndex == 0 ||
              chatState.messages[reverseIndex - 1].senderId != msg.senderId;
          final isLast = reverseIndex == chatState.messages.length - 1 ||
              chatState.messages[reverseIndex + 1].senderId != msg.senderId;

          return Column(
            key: showUnreadDivider ? _unreadAnchorKey : null,
            children: [
              if (showDate) _DateChip(date: msg.createdAt),
              if (showUnreadDivider)
                _UnreadDivider(count: chatState.unreadCountAtOpen),
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
  bool get _isAudio => message.body.startsWith(_audioPrefix);
  String get _imageUrl => message.body.substring(_imagePrefix.length);

  String get _audioUrl {
    final rest = message.body.substring(_audioPrefix.length);
    final pipe = rest.indexOf('|');
    return pipe == -1 ? rest : rest.substring(0, pipe);
  }

  int get _audioDurationSec {
    final rest = message.body.substring(_audioPrefix.length);
    final pipe = rest.indexOf('|');
    if (pipe == -1) return 0;
    return int.tryParse(rest.substring(pipe + 1)) ?? 0;
  }

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
              : _isAudio
                  ? _AudioContent(
                      url: _audioUrl,
                      durationSec: _audioDurationSec,
                      isMe: isMe,
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

// ── Icono de ticks (estilo WhatsApp: 1 gris = enviado, 2 azul = leído)

class _TickIcon extends StatelessWidget {
  const _TickIcon({required this.isPending, required this.isRead});

  final bool isPending;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    if (isPending) {
      return Icon(
        Icons.access_time_rounded,
        size: 14,
        color: Colors.white.withValues(alpha: 0.5),
      );
    }

    if (isRead) {
      return const Icon(
        Icons.done_all_rounded,
        size: 15,
        color: Color(0xFF53BDEB),
      );
    }

    return Icon(
      Icons.done_rounded,
      size: 15,
      color: Colors.white.withValues(alpha: 0.55),
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
    return GestureDetector(
      onTap: () => _openChatImage(context, url),
      child: ClipRRect(
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
      ),
    );
  }
}

void _openChatImage(BuildContext context, String url) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _ChatImageViewer(url: url),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _ChatImageViewer extends StatelessWidget {
  const _ChatImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2,
            ),
            errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1
        ? '1 mensaje no leído'
        : '$count mensajes no leídos';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF182229),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF00BFA5),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Contenido de audio en burbuja ─────────────────────────────────────────────

class _AudioContent extends StatefulWidget {
  const _AudioContent({
    required this.url,
    required this.durationSec,
    required this.isMe,
    required this.timestamp,
  });

  final String url;
  final int durationSec;
  final bool isMe;
  final Widget timestamp;

  @override
  State<_AudioContent> createState() => _AudioContentState();
}

class _AudioContentState extends State<_AudioContent> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    await _player.play(UrlSource(widget.url));
    if (mounted) setState(() => _playing = true);
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isMe ? Colors.white : const Color(0xFF00A884);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _togglePlayback,
              customBorder: const CircleBorder(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: iconColor,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(18, (i) {
                    final h = 4.0 + (i % 5) * 2.5;
                    return Container(
                      width: 3,
                      height: h,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: _playing ? 0.85 : 0.45,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(widget.durationSec),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          widget.timestamp,
        ],
      ),
    );
  }
}

// ── Barra de grabación (estilo WhatsApp) ──────────────────────────────────────

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.seconds,
    required this.onCancel,
    required this.onSend,
  });

  final int seconds;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  static const _footerColor = Color(0xFF202C33);
  static const _waGreen = Color(0xFF00A884);

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      color: _footerColor,
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
      child: Row(
        children: [
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFF8696A0)),
            tooltip: 'Cancelar',
          ),
          const SizedBox(width: 4),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFFF5252),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatTime(seconds),
            style: const TextStyle(
              color: Color(0xFFE9EDEF),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          const Text(
            'Grabando…',
            style: TextStyle(color: Color(0xFF8696A0), fontSize: 14),
          ),
          const SizedBox(width: 12),
          Material(
            color: _waGreen,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onSend,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.send_rounded, color: Colors.white, size: 24),
              ),
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

class _InputBar extends StatefulWidget {
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
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  // Colores WhatsApp dark mode
  static const _footerColor = Color(0xFF202C33);
  static const _inputColor = Color(0xFF2A3942);
  static const _iconColor = Color(0xFF8696A0);
  static const _waGreen = Color(0xFF00A884);
  static const _textColor = Color(0xFFE9EDEF);
  static const _actionSize = 48.0;
  static const _textStyle = TextStyle(color: _textColor, fontSize: 16, height: 1.25);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool _isMultiline(double textMaxWidth) {
    final text = widget.controller.text;
    if (text.contains('\n')) return true;
    if (text.isEmpty || textMaxWidth <= 0) return false;

    final painter = TextPainter(
      text: TextSpan(text: text, style: _textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: textMaxWidth);
    return painter.computeLineMetrics().length > 1;
  }

  Widget _barIcon({
    required Widget icon,
    required VoidCallback onPressed,
    String? tooltip,
    EdgeInsets padding = EdgeInsets.zero,
    bool bottomAligned = false,
  }) {
    return Padding(
      padding: padding.copyWith(
        bottom: padding.bottom + (bottomAligned ? 4 : 0),
      ),
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        const outerHPad = 12.0; // 6 + 6
        const iconSlot = 40.0;
        final attachSlot = widget.hasText ? 0.0 : iconSlot;
        final textMaxWidth = constraints.maxWidth -
            outerHPad -
            _actionSize -
            6 -
            iconSlot -
            attachSlot -
            12;
        final isMultiline = _isMultiline(textMaxWidth);
        final align =
            isMultiline ? CrossAxisAlignment.end : CrossAxisAlignment.center;

        return Container(
          color: _footerColor,
          padding: EdgeInsets.fromLTRB(6, 6, 6, 6 + bottomInset),
          child: Row(
            crossAxisAlignment: align,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: _actionSize),
                  decoration: BoxDecoration(
                    color: _inputColor,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    crossAxisAlignment: align,
                    children: [
                      _barIcon(
                        padding: const EdgeInsets.only(left: 2),
                        bottomAligned: isMultiline,
                        onPressed: widget.onToggleEmoji,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            widget.showingEmoji
                                ? Icons.keyboard_rounded
                                : Icons.emoji_emotions_outlined,
                            key: ValueKey(widget.showingEmoji),
                            color: widget.showingEmoji ? _waGreen : _iconColor,
                            size: 24,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          minLines: 1,
                          maxLines: 6,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => widget.onSend(),
                          onChanged: (_) => setState(() {}),
                          onTap: () {
                            if (widget.showingEmoji) widget.onToggleEmoji();
                          },
                          style: _textStyle,
                          decoration: InputDecoration(
                            hintText: 'Mensaje',
                            hintStyle: const TextStyle(
                              color: _iconColor,
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: isMultiline ? 8 : 12,
                            ),
                          ),
                        ),
                      ),
                      if (!widget.hasText)
                        _barIcon(
                          padding: const EdgeInsets.only(right: 2),
                          bottomAligned: isMultiline,
                          onPressed: widget.onAttach,
                          tooltip: 'Adjuntar imagen',
                          icon: Transform.rotate(
                            angle: 0.785398, // 45° — clip estilo WhatsApp
                            child: const Icon(
                              Icons.attach_file_rounded,
                              color: _iconColor,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Botón enviar / micrófono
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Material(
                  key: ValueKey(widget.hasText),
                  color: _waGreen,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: widget.hasText ? widget.onSend : widget.onMicTap,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: _actionSize,
                      height: _actionSize,
                      child: Icon(
                        widget.hasText
                            ? Icons.send_rounded
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
