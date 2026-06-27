import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../features/saved/providers/saved_professional_providers.dart';

/// Botón de corazón para guardar / quitar un profesional de favoritos.
class SaveProfessionalButton extends ConsumerStatefulWidget {
  const SaveProfessionalButton({
    super.key,
    required this.professionalId,
    this.compact = false,
    this.showLabel = false,
    this.iconSize = 22,
  });

  final String professionalId;
  final bool compact;
  final bool showLabel;
  final double iconSize;

  @override
  ConsumerState<SaveProfessionalButton> createState() =>
      _SaveProfessionalButtonState();
}

class _SaveProfessionalButtonState extends ConsumerState<SaveProfessionalButton> {
  bool _busy = false;

  Future<void> _toggle(bool currentlySaved) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.push(
        AppRoutes.loginWithRedirect(
          AppRoutes.companyDetailPath(widget.professionalId),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(savedProfessionalIdsProvider.notifier)
          .toggle(widget.professionalId);
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('PGRST205') ||
                e.toString().contains('saved_professionals')
            ? 'El servidor aún no tiene la tabla de guardados. Contacta con soporte.'
            : 'No se pudo guardar. Inténtalo de nuevo.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idsAsync = ref.watch(savedProfessionalIdsProvider);
    final isSaved = idsAsync.maybeWhen(
      data: (ids) => ids.contains(widget.professionalId),
      orElse: () => false,
    );

    if (widget.compact) {
      return Material(
        color: Colors.black.withValues(alpha: 0.42),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : () => _toggle(isSaved),
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: _busy
                ? SizedBox(
                    width: widget.iconSize,
                    height: widget.iconSize,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isSaved ? Icons.favorite : Icons.favorite_border,
                    size: widget.iconSize,
                    color: isSaved ? Colors.redAccent : Colors.white,
                  ),
          ),
        ),
      );
    }

    if (widget.showLabel) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _toggle(isSaved),
          icon: _busy
              ? SizedBox(
                  width: widget.iconSize,
                  height: widget.iconSize,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isSaved ? Icons.favorite : Icons.favorite_border,
                  color: isSaved ? Colors.redAccent : null,
                ),
          label: Text(isSaved ? 'Guardado en tu lista' : 'Guardar profesional'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isSaved ? Colors.redAccent : AppTheme.textPrimary,
            side: BorderSide(
              color: isSaved
                  ? Colors.redAccent.withValues(alpha: 0.6)
                  : AppTheme.textSecondary.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: isSaved ? 'Quitar de guardados' : 'Guardar profesional',
      onPressed: _busy ? null : () => _toggle(isSaved),
      icon: _busy
          ? SizedBox(
              width: widget.iconSize,
              height: widget.iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isSaved ? Colors.redAccent : AppTheme.textSecondary,
              ),
            )
          : Icon(
              isSaved ? Icons.favorite : Icons.favorite_border,
              size: widget.iconSize,
              color: isSaved ? Colors.redAccent : AppTheme.textSecondary,
            ),
    );
  }
}
