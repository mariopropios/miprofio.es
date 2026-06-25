import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Muestra uno o varios oficios de forma compacta (tarjetas, detalle).
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
          _Tag(label: '+$hidden', compact: compact, muted: true),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    this.highlighted = false,
    this.compact = false,
    this.muted = false,
  });

  final String label;
  final bool highlighted;
  final bool compact;
  final bool muted;

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

    return Container(
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
  }
}
