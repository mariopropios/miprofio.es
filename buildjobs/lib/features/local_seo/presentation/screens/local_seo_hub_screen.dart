import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/local_seo.dart';
import '../../../../core/constants/profession_catalog.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/seo/web_seo_meta.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/responsive_layout.dart';

/// Hub SEO: `/candeleda`, `/madrigal-de-la-vera`, `/villanueva-de-la-vera`.
class LocalSeoHubScreen extends ConsumerStatefulWidget {
  const LocalSeoHubScreen({super.key, required this.location});

  final LocalSeoLocation location;

  @override
  ConsumerState<LocalSeoHubScreen> createState() => _LocalSeoHubScreenState();
}

class _LocalSeoHubScreenState extends ConsumerState<LocalSeoHubScreen> {
  bool _showAllProfessions = false;

  @override
  void initState() {
    super.initState();
    _applyMeta();
  }

  @override
  void didUpdateWidget(covariant LocalSeoHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.slug != widget.location.slug) {
      _applyMeta();
      _showAllProfessions = false;
    }
  }

  void _applyMeta() {
    final loc = widget.location;
    applyWebSeoMeta(
      title: LocalSeo.hubTitle(loc),
      description: LocalSeo.hubDescription(loc),
      canonicalPath: LocalSeo.hubPath(loc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final popularNames = LocalSeo.popularProfessionNames.toSet();
    final popular = LocalSeo.popularProfessionNames
        .map(ProfessionCatalog.findByName)
        .whereType<ProfessionItem>()
        .toList();
    final more = ProfessionCatalog.allProfessions
        .where((p) => !popularNames.contains(p.name))
        .toList();

    return Scaffold(
      primary: false,
      appBar: AppBar(
        title: Text(loc.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: ResponsiveContent(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            0,
            isDesktop ? 12 : 8,
            0,
            24 +
                MediaQuery.paddingOf(context).bottom +
                (isDesktop ? 24 : kBottomNavigationBarHeight),
          ),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocalSeo.hubH1(loc),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    LocalSeo.hubIntro(loc),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '¿Qué necesitas?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Elige un oficio y verás profesionales cerca.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in popular)
                  ActionChip(
                    label: Text(p.name),
                    onPressed: () => context.go(
                      LocalSeo.professionPath(loc, p.name),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(
                  () => _showAllProfessions = !_showAllProfessions,
                ),
                child: Text(
                  _showAllProfessions
                      ? 'Ocultar más oficios'
                      : 'Ver más oficios (${more.length})',
                ),
              ),
            ),
            if (_showAllProfessions) ...[
              const SizedBox(height: 8),
              _HubMoreProfessionSections(
                location: loc,
                excludeNames: popularNames,
              ),
            ],
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: PremiumButton(
                label: 'Soy profesional · Publicar gratis',
                onPressed: () =>
                    context.push(AppRoutes.professionalRegister),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Pueblos vecinos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final other in LocalSeo.neighborsOf(loc))
                  OutlinedButton(
                    onPressed: () => context.go(LocalSeo.hubPath(other)),
                    child: Text(other.name),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Oficios restantes agrupados en las 3 secciones del catálogo (chips).
class _HubMoreProfessionSections extends StatelessWidget {
  const _HubMoreProfessionSections({
    required this.location,
    required this.excludeNames,
  });

  final LocalSeoLocation location;
  final Set<String> excludeNames;

  @override
  Widget build(BuildContext context) {
    final sections = <({ServiceSectionGroup group, List<ProfessionItem> items})>[];
    for (final group in ProfessionCatalog.serviceSectionGroups) {
      final items = ProfessionCatalog.professionsForBrowseGroup(group.id)
          .where((p) => !excludeNames.contains(p.name))
          .toList(growable: false);
      if (items.isEmpty) continue;
      sections.add((group: group, items: items));
    }

    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 24),
          Text(
            sections[i].group.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in sections[i].items)
                ActionChip(
                  label: Text(p.name),
                  onPressed: () => context.go(
                    LocalSeo.professionPath(location, p.name),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
