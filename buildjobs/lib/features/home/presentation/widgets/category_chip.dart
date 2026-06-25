import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/spring_pressable.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;

  /// Texto más claro para buena legibilidad sobre fondo oscuro
  static const Color _labelDefault = Color(0xFFECECF0);
  static const Color _labelSelected = Colors.white;

  @override
  Widget build(BuildContext context) {
    return SpringPressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: AnimatedContainer(
        duration: AppTheme.hoverDuration,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.28)
              : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.7)
                : const Color(0xFF3A444D),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _labelSelected : _labelDefault,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
