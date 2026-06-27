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
  late String _selectedBrowseGroupId;

  @override
  void initState() {
    super.initState();
    _selectedBrowseGroupId = ProfessionCatalog.serviceSectionGroups.first.id;
  }

  ServiceSectionGroup get _activeBrowseGroup =>
      ProfessionCatalog.serviceGroupById(_selectedBrowseGroupId)!;

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
    if (professions.isEmpty) return;

    final available = _availableCategories(professions);
    final next = Set<String>.from(
      widget.selectedCategories.where(available.contains),
    );

    if (available.contains('reparaciones') ||
        available.contains('reformas')) {
      next.addAll(['reparaciones', 'reformas']);
    }
    if (available.contains('mantenimiento')) {
      next.add('mantenimiento');
    }

    if (next != widget.selectedCategories) {
      widget.onCategoriesChanged!(next);
    }
  }

  void _toggleServiceGroup(ServiceSectionGroup group) {
    if (widget.onCategoriesChanged == null) return;
    widget.onCategoriesChanged!(
      ProfessionCatalog.toggleServiceGroup(group, widget.selectedCategories),
    );
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
          _activeBrowseGroup.title,
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
            itemCount: ProfessionCatalog.serviceSectionGroups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final group = ProfessionCatalog.serviceSectionGroups[index];
              return MotherCategoryChip(
                label: group.label,
                selected: _selectedBrowseGroupId == group.id,
                onTap: () => setState(() => _selectedBrowseGroupId = group.id),
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
            key: ValueKey(_selectedBrowseGroupId),
            spacing: 8,
            runSpacing: 8,
            children: ProfessionCatalog.professionsForBrowseGroup(
              _selectedBrowseGroupId,
            ).map((prof) {
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
        // ── Selector de categorías (solo si hay solape entre secciones) ─────
        if (widget.onCategoriesChanged != null) ...[
          _CategorySelector(
            available: _availableCategories(widget.selectedProfessions),
            selected: widget.selectedCategories,
            onToggleGroup: _toggleServiceGroup,
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
    required this.onToggleGroup,
    this.topPadding = 20,
  });

  final Set<String> available;
  final Set<String> selected;
  final ValueChanged<ServiceSectionGroup> onToggleGroup;
  final double topPadding;

  bool _groupAvailable(ServiceSectionGroup group) =>
      group.categoryIds.any(available.contains);

  bool _groupFullySelected(ServiceSectionGroup group) =>
      group.categoryIds.every(selected.contains);

  @override
  Widget build(BuildContext context) {
    final groups = ProfessionCatalog.serviceSectionGroups;

    if (available.isEmpty) return const SizedBox.shrink();

    final applicable =
        groups.where((g) => _groupAvailable(g)).toList(growable: false);

    if (applicable.isEmpty) return const SizedBox.shrink();

    if (applicable.length == 1 && _groupFullySelected(applicable.first)) {
      return const SizedBox.shrink();
    }

    return _buildSelector(
      context,
      applicable,
      enabledOnly: true,
      topPadding: topPadding,
    );
  }

  Widget _buildSelector(
    BuildContext context,
    List<ServiceSectionGroup> groups, {
    required bool enabledOnly,
    double topPadding = 20,
  }) {
    final canToggle = !enabledOnly || available.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿En qué secciones trabajas?',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            canToggle
                ? 'Marca Reparaciones y Reformas, Mantenimiento u otras secciones.'
                : 'Selecciona tus oficios abajo para activar estas opciones.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: groups.map((group) {
              final isEnabled = !enabledOnly || _groupAvailable(group);
              final isOn =
                  ProfessionCatalog.isServiceGroupSelected(group, selected);
              return GestureDetector(
                onTap: isEnabled ? () => onToggleGroup(group) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isOn && isEnabled
                        ? AppTheme.primary
                        : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOn && isEnabled
                          ? AppTheme.primary
                          : const Color(0xFF3A444D),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOn && isEnabled
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 16,
                        color: !isEnabled
                            ? AppTheme.textSecondary.withValues(alpha: 0.35)
                            : isOn
                                ? Colors.white
                                : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        group.label,
                        style: TextStyle(
                          color: !isEnabled
                              ? AppTheme.textSecondary.withValues(alpha: 0.35)
                              : isOn
                                  ? Colors.white
                                  : AppTheme.textSecondary,
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
