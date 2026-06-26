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
  });

  final String? selectedProfession;
  /// Llamado con (professionName, categoryId) al pulsar un chip de oficio.
  final void Function(String profession, String categoryId)? onProfessionTap;

  @override
  State<ProfessionFilterSection> createState() =>
      _ProfessionFilterSectionState();
}

class _ProfessionFilterSectionState extends State<ProfessionFilterSection> {
  late String _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = _resolveInitialCategory();
  }

  @override
  void didUpdateWidget(covariant ProfessionFilterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedProfession != widget.selectedProfession) {
      setState(() => _selectedCategoryId = _resolveInitialCategory());
    }
  }

  String _resolveInitialCategory() {
    if (widget.selectedProfession != null) {
      final item = ProfessionCatalog.findByName(widget.selectedProfession!);
      if (item != null) return item.categoryId;
    }
    return ProfessionCatalog.categories.first.id;
  }

  ProfessionCategory get _activeCategory =>
      ProfessionCatalog.categoryById(_selectedCategoryId)!;

  void _handleProfessionTap(String name) =>
      widget.onProfessionTap?.call(name, _selectedCategoryId);

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
              onTap: () => ProfessionCatalogSheet.show(context),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Tabs de categoría (scroll horizontal) ─────────────────────────
        SizedBox(
          height: 36,
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
        const SizedBox(height: 10),

        // ── Chips de oficio ────────────────────────────────────────────────
        // AnimatedSize suaviza el cambio de altura en desktop (más/menos chips).
        // AnimatedSwitcher hace fade + deslizamiento vertical suave al cambiar
        // de categoría, evitando el crossfade brusco.
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            ),
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topLeft,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            ),
            child: isMobile
                ? _MobileChipsRow(
                    key: ValueKey(_selectedCategoryId),
                    professions: _activeCategory.professions,
                    selectedProfession: widget.selectedProfession,
                    onTap: _handleProfessionTap,
                  )
                : _DesktopChipsWrap(
                    key: ValueKey(_selectedCategoryId),
                    professions: _activeCategory.professions,
                    selectedProfession: widget.selectedProfession,
                    onTap: _handleProfessionTap,
                  ),
          ),
        ),
      ],
    );
  }
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
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: professions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prof = professions[index];
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: professions.map((prof) {
        return ProfessionChip(
          profession: prof,
          selected: selectedProfession == prof.name,
          onTap: () => onTap(prof.name),
        );
      }).toList(),
    );
  }
}
