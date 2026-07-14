import 'package:flutter/material.dart';

import '../../../../core/constants/profession_catalog.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import 'profession_catalog_sheet.dart';
import 'profession_chip.dart';

/// Sección de filtrado por profesión: categorías madre + chips segmentados.
/// En móvil los chips se muestran en scroll horizontal (1 fila compacta).
/// En desktop se expanden en Wrap para mayor visibilidad.
class ProfessionFilterSection extends StatefulWidget {
  const ProfessionFilterSection({
    super.key,
    this.selectedProfession,
    this.onProfessionTap,
    this.preservedCity,
    this.preservedQuery,
  });

  final String? selectedProfession;
  /// Llamado con (professionName, categoryId) al pulsar un chip de oficio.
  final void Function(String profession, String categoryId)? onProfessionTap;
  final String? preservedCity;
  final String? preservedQuery;

  @override
  State<ProfessionFilterSection> createState() =>
      _ProfessionFilterSectionState();
}

class _ProfessionFilterSectionState extends State<ProfessionFilterSection> {
  late String _selectedBrowseGroupId;

  @override
  void initState() {
    super.initState();
    _selectedBrowseGroupId = _resolveInitialBrowseGroup();
  }

  @override
  void didUpdateWidget(covariant ProfessionFilterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProfession != widget.selectedProfession) {
      setState(() => _selectedBrowseGroupId = _resolveInitialBrowseGroup());
    }
  }

  String _resolveInitialBrowseGroup() {
    if (widget.selectedProfession != null) {
      final item = ProfessionCatalog.findByName(widget.selectedProfession!);
      if (item != null) {
        for (final group in ProfessionCatalog.serviceSectionGroups) {
          if (group.categoryIds.contains(item.categoryId)) {
            return group.id;
          }
        }
      }
    }
    return ProfessionCatalog.serviceSectionGroups.first.id;
  }

  ServiceSectionGroup get _activeBrowseGroup =>
      ProfessionCatalog.serviceGroupById(_selectedBrowseGroupId)!;

  List<ProfessionItem> get _visibleProfessions =>
      ProfessionCatalog.professionsForBrowseGroup(_selectedBrowseGroupId);

  void _handleProfessionTap(String name) {
    final item = ProfessionCatalog.findByName(name);
    final categoryId = item?.categoryId ?? _activeBrowseGroup.categoryIds.first;
    widget.onProfessionTap?.call(name, categoryId);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Título + Ver todo ──────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                'Profesiones',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            VerTodoChip(
              onTap: () => ProfessionCatalogSheet.show(
                context,
                city: widget.preservedCity,
                query: widget.preservedQuery,
                onProfessionSelected: widget.onProfessionTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Tabs de categoría ─────────────────────────────────────────────
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final group in ProfessionCatalog.serviceSectionGroups)
              MotherCategoryChip(
                label: group.label,
                selected: _selectedBrowseGroupId == group.id,
                onTap: () => setState(() => _selectedBrowseGroupId = group.id),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Chips de oficio ────────────────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          clipBehavior: Clip.none,
          child: isMobile
              ? _MobileChipsRow(
                  key: ValueKey(_selectedBrowseGroupId),
                  professions: _visibleProfessions,
                  selectedProfession: widget.selectedProfession,
                  onTap: _handleProfessionTap,
                )
              : _DesktopChipsWrap(
                  key: ValueKey(_selectedBrowseGroupId),
                  professions: _visibleProfessions,
                  selectedProfession: widget.selectedProfession,
                  onTap: _handleProfessionTap,
                ),
        ),
      ],
    );
  }
}

/// Mueve el oficio seleccionado al principio de la lista, sin modificar el original.
List<ProfessionItem> _sortedWithSelectedFirst(
  List<ProfessionItem> professions,
  String? selectedProfession,
) {
  if (selectedProfession == null) return professions;
  final idx = professions.indexWhere((p) => p.name == selectedProfession);
  if (idx <= 0) return professions;
  final sorted = List<ProfessionItem>.from(professions);
  sorted.insert(0, sorted.removeAt(idx));
  return sorted;
}

/// Scroll horizontal de una fila (móvil) — compacto y sin saltos de línea.
class _MobileChipsRow extends StatelessWidget {
  const _MobileChipsRow({
    super.key,
    required this.professions,
    required this.selectedProfession,
    required this.onTap,
  });

  final List<ProfessionItem> professions;
  final String? selectedProfession;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedWithSelectedFirst(professions, selectedProfession);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prof = sorted[index];
          return ProfessionChip(
            profession: prof,
            selected: selectedProfession == prof.name,
            onTap: () => onTap(prof.name),
          );
        },
      ),
    );
  }
}

/// Wrap de varias filas (desktop) — más descriptivo con más espacio disponible.
class _DesktopChipsWrap extends StatelessWidget {
  const _DesktopChipsWrap({
    super.key,
    required this.professions,
    required this.selectedProfession,
    required this.onTap,
  });

  final List<ProfessionItem> professions;
  final String? selectedProfession;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedWithSelectedFirst(professions, selectedProfession);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sorted.map((prof) {
        return ProfessionChip(
          profession: prof,
          selected: selectedProfession == prof.name,
          onTap: () => onTap(prof.name),
        );
      }).toList(),
    );
  }
}
