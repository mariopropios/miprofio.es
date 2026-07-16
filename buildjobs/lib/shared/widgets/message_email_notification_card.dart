import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_theme.dart';

/// Activa avisos por email (mensajes, reseñas y respuestas).
class MessageEmailNotificationCard extends ConsumerStatefulWidget {
  const MessageEmailNotificationCard({super.key});

  @override
  ConsumerState<MessageEmailNotificationCard> createState() =>
      _MessageEmailNotificationCardState();
}

class _MessageEmailNotificationCardState
    extends ConsumerState<MessageEmailNotificationCard> {
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(currentProfileProvider.future);
    if (!mounted) return;
    setState(() => _enabled = profile?.messageEmailNotifications ?? true);
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() {
      _busy = true;
      _enabled = value;
    });

    try {
      await ref.read(profileRepositoryProvider).updateMessageEmailNotifications(
            userId: userId,
            enabled: value,
          );
      ref.invalidate(currentProfileProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _enabled = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la preferencia')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    if (enabled == null) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: enabled,
        onChanged: _busy ? null : _toggle,
        activeThumbColor: AppTheme.primary,
        title: const Text(
          'Avisos por email',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          enabled
              ? 'Te avisamos por email de mensajes nuevos, reseñas y respuestas (ideal en iPhone).'
              : 'No recibirás emails de mensajes, reseñas ni respuestas.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
        ),
        secondary: Icon(
          enabled ? Icons.mail_outline : Icons.mark_email_unread_outlined,
          color: enabled ? AppTheme.primary : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
