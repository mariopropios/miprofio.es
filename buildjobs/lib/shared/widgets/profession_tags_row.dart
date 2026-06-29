import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// Muestra uno o varios oficios de forma compacta (tarjetas, detalle).
/// El tag "+N" es tappable y abre un panel con todos los oficios ocultos.
class ProfessionTagsRow extends StatelessWidget {
  const ProfessionTagsRow({
    super.key,
    required this.professions,
    this.maxVisible = 3,
    this.highlight,
    this.compact = false,
  });

  final List<String> professions;
  final int maxVisible;
  final String? highlight;
  final bool compact;

  void _showAll(BuildContext context) {
    // Capturamos el router y el navigator antes de mostrar el sheet.
    // El listener cierra el sheet si el usuario cambia de tab o pantalla.
    final router = GoRouter.of(context);
    final navigatorState = Navigator.of(context);
    bool isOpen = true;

    void closeOnNavigate() {
      if (!isOpen) return;
      isOpen = false;
      try {
        navigatorState.pop();
      } catch (_) {}
    }

    router.routerDelegate.addListener(closeOnNavigate);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AllProfessionsSheet(
        professions: professions,
        highlight: highlight,
      ),
    ).whenComplete(() {
      isOpen = false;
      router.routerDelegate.removeListener(closeOnNavigate);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (professions.isEmpty) return const SizedBox.shrink();

    final visible = professions.take(maxVisible).toList();
    final hidden = professions.length - visible.length;

    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 4 : 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...visible.map((name) => _Tag(
              label: name,
              highlighted: highlight != null &&
                  name.toLowerCase() == highlight!.toLowerCase(),
              compact: compact,
            )),
        if (hidden > 0)
          _Tag(
            label: '+$hidden',
            compact: compact,
            muted: true,
            onTap: () => _showAll(context),
          ),
      ],
    );
  }
}

// ── Hoja con todos los oficios ────────────────────────────────────────────────

class _AllProfessionsSheet extends StatelessWidget {
  const _AllProfessionsSheet({
    required this.professions,
    this.highlight,
  });

  final List<String> professions;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Oficios',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: professions
                  .map((name) => _Tag(
                        label: name,
                        highlighted: highlight != null &&
                            name.toLowerCase() == highlight!.toLowerCase(),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tag ───────────────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    this.highlighted = false,
    this.compact = false,
    this.muted = false,
    this.onTap,
  });

  final String label;
  final bool highlighted;
  final bool compact;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = muted
        ? AppTheme.surfaceElevated
        : highlighted
            ? AppTheme.primary.withValues(alpha: 0.28)
            : AppTheme.primary.withValues(alpha: 0.16);

    final border = muted
        ? AppTheme.divider
        : highlighted
            ? AppTheme.primary.withValues(alpha: 0.7)
            : AppTheme.primary.withValues(alpha: 0.4);

    final textColor = muted
        ? AppTheme.textSecondary
        : highlighted
            ? Colors.white
            : AppTheme.primary;

    final container = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (onTap == null) return container;

    return GestureDetector(
      onTap: onTap,
      child: container,
    );
  }
}
