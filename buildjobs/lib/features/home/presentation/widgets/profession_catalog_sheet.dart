import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/profession_catalog.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import 'profession_chip.dart';

/// Grid completo del catálogo de oficios (modal / bottom sheet).
class ProfessionCatalogSheet extends StatefulWidget {
  const ProfessionCatalogSheet({
    super.key,
    this.multiSelect = false,
    this.selectedProfessions = const {},
    this.onToggleProfession,
  });

  final bool multiSelect;
  final Set<String> selectedProfessions;
  final ValueChanged<String>? onToggleProfession;

  static Future<void> show(BuildContext context) {
    return _present(context, const ProfessionCatalogSheet());
  }

  static Future<void> showForMultiSelect(
    BuildContext context, {
    required Set<String> selected,
    required ValueChanged<String> onToggle,
  }) {
    return _present(
      context,
      ProfessionCatalogSheet(
        multiSelect: true,
        selectedProfessions: selected,
        onToggleProfession: onToggle,
      ),
    );
  }

  static Future<void> _present(BuildContext context, Widget sheet) {
    final isMobile = ResponsiveLayout.isMobile(context);

    if (isMobile) {
      final height = MediaQuery.sizeOf(context).height * 0.88;
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.scaffoldBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => SizedBox(height: height, child: sheet),
      );
    }

    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.scaffoldBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: sheet,
        ),
      ),
    );
  }

  @override
  State<ProfessionCatalogSheet> createState() => _ProfessionCatalogSheetState();
}

class _ProfessionCatalogSheetState extends State<ProfessionCatalogSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedProfessions);
  }

  void _handleToggle(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
    widget.onToggleProfession?.call(name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.multiSelect
                      ? 'Selecciona oficios'
                      : 'Catálogo de oficios',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            widget.multiSelect
                ? 'Puedes marcar varios oficios a la vez.'
                : 'Explora las especialidades de hogar y mantenimiento, organizadas en 2 áreas.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: ProfessionCatalog.serviceSectionGroups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final group = ProfessionCatalog.serviceSectionGroups[index];
              return _CategoryBlock(
                title: group.title,
                professions:
                    ProfessionCatalog.professionsForBrowseGroup(group.id),
                multiSelect: widget.multiSelect,
                selectedProfessions: _selected,
                onToggleProfession: _handleToggle,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({
    required this.title,
    required this.professions,
    required this.multiSelect,
    required this.selectedProfessions,
    this.onToggleProfession,
  });

  final String title;
  final List<ProfessionItem> professions;
  final bool multiSelect;
  final Set<String> selectedProfessions;
  final ValueChanged<String>? onToggleProfession;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: professions.map((prof) {
            return ProfessionChip(
              profession: prof,
              selected: selectedProfessions.contains(prof.name),
              onTap: () {
                if (multiSelect) {
                  onToggleProfession?.call(prof.name);
                } else {
                  Navigator.pop(context);
                  context.go(AppRoutes.searchWith(profession: prof.name));
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
