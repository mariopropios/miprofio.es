import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/message.dart';
import '../../data/chat_repository.dart';

final _chatRepoProvider = Provider((ref) => ChatRepository());

// Reactivo al usuario: si cambia sesión, re-fetcha automáticamente
final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  ref.watch(currentUserProvider); // invalida cuando cambia la sesión
  return ref.read(_chatRepoProvider).getConversations();
});

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Recargar al entrar
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.invalidate(conversationsProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(conversationsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mensajes')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      body: convAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No se pudieron cargar los mensajes',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Comprueba tu conexión e inténtalo de nuevo.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  onPressed: () => ref.invalidate(conversationsProvider),
                ),
              ],
            ),
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 64, color: AppTheme.textSecondary),
                    SizedBox(height: 16),
                    Text(
                      'Todavía no tienes conversaciones.\nEncuentra un profesional y envíale un mensaje.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppTheme.divider),
              itemBuilder: (context, index) {
                final conv = conversations[index];
                return _ConversationTile(conversation: conv);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: _Avatar(
        name: conversation.professionalName,
        photoUrl: conversation.professionalPhoto,
      ),
      title: Text(
        conversation.professionalName,
        style: const TextStyle(
            fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
      ),
      subtitle: conversation.lastMessage != null
          ? Text(
              conversation.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            )
          : const Text(
              'Conversación iniciada',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
      trailing: conversation.lastMessageAt != null
          ? Text(
              _formatDate(conversation.lastMessageAt!),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12),
            )
          : null,
      onTap: () => context.push(
        AppRoutes.chatPath(conversation.professionalId),
        extra: {
          'name': conversation.professionalName,
          'photo': conversation.professionalPhoto,
          'conversationId': conversation.id,
        },
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month}';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(photoUrl!),
        backgroundColor: AppTheme.surfaceElevated,
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}
