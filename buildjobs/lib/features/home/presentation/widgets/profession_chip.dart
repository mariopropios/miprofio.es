import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/profession_catalog.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/spring_pressable.dart';

/// Chip de oficio con tooltip iOS en web y bottom sheet en móvil.
class ProfessionChip extends StatelessWidget {
  const ProfessionChip({
    super.key,
    required this.profession,
    this.selected = false,
    this.onTap,
  });

  final ProfessionItem profession;
  final bool selected;
  final VoidCallback? onTap;

  static const Color _labelDefault = Color(0xFFECECF0);

  static void showDescription(
    BuildContext context,
    ProfessionItem item, {
    VoidCallback? onSelect,
  }) {
    showDescriptionSheet(context, item, onSelect: onSelect);
  }

  static void showDescriptionDialog(
    BuildContext context,
    ProfessionItem item, {
    VoidCallback? onSelect,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text(
          item.name,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          item.description,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          if (onSelect != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                onSelect();
              },
              child: const Text('Buscar profesionales'),
            ),
        ],
      ),
    );
  }

  static void showDescriptionSheet(
    BuildContext context,
    ProfessionItem item, {
    VoidCallback? onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              item.name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.description,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            if (onSelect != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: SpringPressable(
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelect();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Text(
                      'Buscar profesionales',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _supportsHoverTooltip =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    // Decoración compartida para el chip completo
    final decoration = BoxDecoration(
      color: selected ? AppTheme.primary : AppTheme.surfaceElevated,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      border: Border.all(
        color: selected ? AppTheme.primary : const Color(0xFF3A444D),
        width: selected ? 1.2 : 1,
      ),
    );

    // El icono ⓘ está FUERA del SpringPressable para que su tap no
    // dispare también la selección del chip.
    Widget chip = AnimatedContainer(
      duration: AppTheme.hoverDuration,
      curve: Curves.easeOutCubic,
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zona tappable: solo el texto selecciona el chip
          SpringPressable(
            onTap: onTap,
            pressedScale: 0.97,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 9, 6, 9),
              child: Text(
                profession.name,
                style: TextStyle(
                  color: selected ? Colors.white : _labelDefault,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
          // Icono ⓘ independiente: solo abre el sheet, nunca selecciona
          GestureDetector(
            onTap: () => showDescription(context, profession, onSelect: onTap),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 9, 10, 9),
              child: Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: selected
                    ? Colors.white.withValues(alpha: 0.9)
                    : AppTheme.textSecondary.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      chip = GestureDetector(
        onLongPress: () => showDescription(
          context,
          profession,
          onSelect: onTap,
        ),
        child: chip,
      );
    }

    if (_supportsHoverTooltip && !isMobile) {
      chip = Tooltip(
        message: profession.description,
        waitDuration: const Duration(milliseconds: 180),
        showDuration: const Duration(seconds: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E252B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
          height: 1.4,
        ),
        child: chip,
      );
    }

    return chip;
  }
}

/// Chip de categoría madre (fila superior horizontal).
class MotherCategoryChip extends StatelessWidget {
  const MotherCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.selectionCount = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int selectionCount;

  @override
  Widget build(BuildContext context) {
    return SpringPressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: AnimatedContainer(
        duration: AppTheme.hoverDuration,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFF3A444D),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFECECF0),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (selectionCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppTheme.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$selectionCount',
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Botón "Ver todo" estilo iOS.
class VerTodoChip extends StatelessWidget {
  const VerTodoChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SpringPressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.5),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded, size: 16, color: AppTheme.primary),
            SizedBox(width: 6),
            Text(
              'Ver todo',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
