import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/message.dart';
import '../../data/chat_repository.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _chatRepoProvider = Provider((ref) => ChatRepository());

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
  }) : super(const _ChatState()) {
    _load();
    _subscribeRealtime();
  }

  final String conversationId;
  final ChatRepository repo;
  final String currentUserId;
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
              final newMsg =
                  ChatMessage.fromJson(payload.newRecord);
              final existing = state.messages;
              // Reemplazar mensaje temporal del mismo remitente/texto si existe
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
            } catch (_) {}
          },
        )
        .subscribe();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Optimistic: añadir con ID temporal
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
      await repo.sendMessage(
          conversationId: conversationId, body: trimmed);

      // Esperar 400 ms para que Realtime lo entregue si está disponible
      await Future.delayed(const Duration(milliseconds: 400));

      // Si el temp sigue ahí (Realtime no lo sustituyó), hacer re-fetch
      if (mounted && state.messages.any((m) => m.id == tempId)) {
        final fresh = await repo.getMessages(conversationId);
        if (mounted) state = state.copyWith(messages: fresh);
      }
    } catch (e) {
      // Revertir el mensaje temporal si falló el envío
      if (mounted) {
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != tempId).toList(),
          error: e.toString(),
        );
        rethrow;
      }
    }
  }

  Future<void> markAsRead() => repo.markAsRead(conversationId);

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
    void openProfessionalProfile() {
      context.push(AppRoutes.companyDetailPath(professionalId));
    }

    final appBar = AppBar(
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
        onTap: openProfessionalProfile,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _Avatar(
                name: professionalName,
                photoUrl: professionalPhoto,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  professionalName,
                  style: const TextStyle(fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Si ya tenemos conversationId (desde la lista de mensajes), lo usamos
    if (conversationId != null) {
      return Scaffold(
        appBar: appBar,
        body: _ChatBody(conversationId: conversationId!),
      );
    }

    // Si no, lo obtenemos/creamos
    final convAsync = ref.watch(_conversationIdProvider(professionalId));
    return Scaffold(
      appBar: appBar,
      body: convAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
        data: (convId) => _ChatBody(conversationId: convId),
      ),
    );
  }
}

// ── Body (se monta cuando ya tenemos conversationId) ──────────────────────────

class _ChatBody extends ConsumerStatefulWidget {
  const _ChatBody({required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends ConsumerState<_ChatBody> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      ref
          .read(_chatNotifierProvider(widget.conversationId).notifier)
          .markAsRead();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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

    // Scroll cuando llegan mensajes nuevos
    ref.listen(_chatNotifierProvider(widget.conversationId),
        (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Column(
      children: [
        Expanded(
          child: _buildMessages(chatState, currentUserId),
        ),
        _InputBar(
          controller: _controller,
          onSend: _send,
        ),
      ],
    );
  }

  Widget _buildMessages(_ChatState chatState, String currentUserId) {
    if (chatState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatState.error != null && chatState.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Error al cargar mensajes: ${chatState.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    if (chatState.messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Empieza la conversación con un mensaje',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        return Column(
          children: [
            if (showDate) _DateChip(date: msg.createdAt),
            _MessageBubble(
              message: msg,
              isMe: isMe,
              isPending: isPending,
            ),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Burbuja de mensaje ────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.isPending = false,
  });

  final ChatMessage message;
  final bool isMe;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.primary.withValues(alpha: isPending ? 0.6 : 1.0)
              : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(
                color: isMe ? Colors.white : AppTheme.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.textSecondary,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  isPending
                      ? SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white
                                .withValues(alpha: 0.6),
                          ),
                        )
                      : Icon(
                          message.isRead
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 13,
                          color: message.isRead
                              ? Colors.white
                              : Colors.white
                                  .withValues(alpha: 0.6),
                        ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

// ── Separador de fecha ────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _label(date),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
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

// ── Barra de input ────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                hintStyle:
                    const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppTheme.primary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onSend,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
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
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }
}
