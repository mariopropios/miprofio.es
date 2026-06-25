import 'package:flutter/material.dart';

import '../../../../core/constants/profession_catalog.dart';
import '../../../../core/theme/app_theme.dart';
import 'profession_catalog_sheet.dart';
import 'profession_chip.dart';

/// Selección múltiple de oficios para registro de profesionales.
class ProfessionMultiSelectSection extends StatefulWidget {
  const ProfessionMultiSelectSection({
    super.key,
    required this.selectedProfessions,
    required this.onSelectionChanged,
    this.selectedCategories = const {},
    this.onCategoriesChanged,
    this.compact = false,
  });

  final Set<String> selectedProfessions;
  final ValueChanged<Set<String>> onSelectionChanged;
  /// Categorías en las que el profesional quiere aparecer al buscar.
  final Set<String> selectedCategories;
  final ValueChanged<Set<String>>? onCategoriesChanged;
  final bool compact;

  @override
  State<ProfessionMultiSelectSection> createState() =>
      _ProfessionMultiSelectSectionState();
}

class _ProfessionMultiSelectSectionState
    extends State<ProfessionMultiSelectSection> {
  late String _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = ProfessionCatalog.categories.first.id;
  }

  ProfessionCategory get _activeCategory =>
      ProfessionCatalog.categoryById(_selectedCategoryId)!;

  void _toggleProfession(String name) {
    final next = Set<String>.from(widget.selectedProfessions);
    if (next.contains(name)) {
      next.remove(name);
    } else {
      next.add(name);
    }
    widget.onSelectionChanged(next);
    // Recalcular categorías disponibles tras cambiar selección
    _autoUpdateCategories(next);
  }

  /// Categorías que contienen al menos una de las profesiones seleccionadas.
  Set<String> _availableCategories(Set<String> professions) {
    final result = <String>{};
    for (final cat in ProfessionCatalog.categories) {
      for (final p in cat.professions) {
        if (professions.contains(p.name)) {
          result.add(cat.id);
          break;
        }
      }
    }
    return result;
  }

  /// Cuando el profesional añade un oficio, auto-selecciona las categorías
  /// nuevas. Cuando quita todos los oficios de una categoría, la deselecciona.
  void _autoUpdateCategories(Set<String> professions) {
    if (widget.onCategoriesChanged == null) return;
    final available = _availableCategories(professions);
    // Mantener las categorías ya elegidas que siguen siendo válidas,
    // y añadir las nuevas (auto-opt-in).
    final next = {
      ...widget.selectedCategories.where(available.contains),
      ...available,
    };
    if (next != widget.selectedCategories) {
      widget.onCategoriesChanged!(next);
    }
  }

  void _toggleCategory(String categoryId) {
    if (widget.onCategoriesChanged == null) return;
    final next = Set<String>.from(widget.selectedCategories);
    if (next.contains(categoryId)) {
      next.remove(categoryId);
    } else {
      next.add(categoryId);
    }
    widget.onCategoriesChanged!(next);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.selectedProfessions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tus especialidades',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: widget.compact ? 20 : null,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    count == 0
                        ? 'Selecciona uno o varios oficios'
                        : '$count oficio${count == 1 ? '' : 's'} seleccionado${count == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: widget.compact ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
            VerTodoChip(
              onTap: () => ProfessionCatalogSheet.showForMultiSelect(
                context,
                selected: widget.selectedProfessions,
                onToggle: _toggleProfession,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _activeCategory.title,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        SizedBox(height: widget.compact ? 10 : 14),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ProfessionCatalog.categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = ProfessionCatalog.categories[index];
              return MotherCategoryChip(
                label: cat.shortName,
                selected: _selectedCategoryId == cat.id,
                onTap: () => setState(() => _selectedCategoryId = cat.id),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: AppTheme.hoverDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Wrap(
            key: ValueKey(_selectedCategoryId),
            spacing: 8,
            runSpacing: 8,
            children: _activeCategory.professions.map((prof) {
              final isSelected =
                  widget.selectedProfessions.contains(prof.name);
              return ProfessionChip(
                profession: prof,
                selected: isSelected,
                onTap: () => _toggleProfession(prof.name),
              );
            }).toList(),
          ),
        ),
        // ── Selector de categorías (si hay categorías con solape) ────────────
        if (widget.onCategoriesChanged != null) ...[
          _CategorySelector(
            available: _availableCategories(widget.selectedProfessions),
            selected: widget.selectedCategories,
            onToggle: _toggleCategory,
          ),
        ],

        if (count > 0) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.selectedProfessions.map((name) {
              return AnimatedContainer(
                duration: AppTheme.hoverDuration,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _toggleProfession(name),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Selector de categorías ────────────────────────────────────────────────────

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.available,
    required this.selected,
    required this.onToggle,
  });

  final Set<String> available;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    // Solo se muestra si hay al menos una categoría disponible
    if (available.isEmpty) return const SizedBox.shrink();

    final cats = ProfessionCatalog.categories
        .where((c) => available.contains(c.id))
        .toList();

    // Si solo hay una categoría disponible y ya está seleccionada, no mostrar
    if (cats.length == 1 && selected.contains(cats.first.id)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿En qué categorías quieres aparecer?',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Los clientes te encontrarán al filtrar por estas secciones.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cats.map((cat) {
              final isOn = selected.contains(cat.id);
              return GestureDetector(
                onTap: () => onToggle(cat.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isOn
                        ? AppTheme.primary
                        : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOn
                          ? AppTheme.primary
                          : const Color(0xFF3A444D),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOn
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: isOn
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat.title,
                        style: TextStyle(
                          color: isOn ? Colors.white : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
