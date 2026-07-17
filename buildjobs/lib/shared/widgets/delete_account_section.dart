import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../features/saved/providers/saved_professional_providers.dart';

/// Bloque «Eliminar cuenta» para el final de las pantallas de edición.
class DeleteAccountSection extends ConsumerStatefulWidget {
  const DeleteAccountSection({
    super.key,
    this.isProfessional = false,
  });

  /// Si true, el texto menciona que la ficha pública dejará de verse.
  final bool isProfessional;

  @override
  ConsumerState<DeleteAccountSection> createState() =>
      _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends ConsumerState<DeleteAccountSection> {
  bool _deleting = false;

  Future<void> _onDeletePressed() async {
    if (_deleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('¿Eliminar tu cuenta?'),
        content: Text(
          widget.isProfessional
              ? 'Se cerrará tu acceso a miProfio.es y tu ficha pública '
                  'dejará de mostrarse. Esta acción no se puede deshacer.'
              : 'Se cerrará tu acceso a miProfio.es y se eliminarán tus datos '
                  'de cuenta. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final typed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _ConfirmDeleteByTypingDialog(),
    );

    if (typed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      await ref.read(authRepositoryProvider).deleteMyAccount();

      ref.invalidate(currentProfileProvider);
      ref.invalidate(currentProfessionalProfileProvider);
      ref.invalidate(currentUserProfessionalViewProvider);
      ref.invalidate(savedProfessionalIdsProvider);
      ref.invalidate(savedProfessionalsProvider);
      invalidateProfessionalListingCaches(ref);

      if (!mounted) return;
      context.go(AppRoutes.home);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu cuenta se ha eliminado.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar la cuenta. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: AppTheme.divider),
        const SizedBox(height: 8),
        Text(
          'Zona peligrosa',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isProfessional
              ? 'Si eliminas la cuenta, tu perfil dejará de ser visible '
                  'para clientes y perderás el acceso.'
              : 'Si eliminas la cuenta, perderás el acceso y tus datos '
                  'asociados.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: _deleting ? null : _onDeletePressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: const BorderSide(color: AppTheme.error),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _deleting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppTheme.error,
                  ),
                )
              : const Text(
                  'Eliminar cuenta',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}

class _ConfirmDeleteByTypingDialog extends StatefulWidget {
  const _ConfirmDeleteByTypingDialog();

  @override
  State<_ConfirmDeleteByTypingDialog> createState() =>
      _ConfirmDeleteByTypingDialogState();
}

class _ConfirmDeleteByTypingDialogState
    extends State<_ConfirmDeleteByTypingDialog> {
  static const _required = 'ELIMINAR';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _ctrl.text.trim().toUpperCase() == _required;

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Confirma la eliminación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Escribe ELIMINAR para confirmar que quieres borrar tu cuenta '
            'para siempre.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'ELIMINAR',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (matches) Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: matches ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: AppTheme.error),
          child: const Text('Eliminar definitivamente'),
        ),
      ],
    );
  }
}
