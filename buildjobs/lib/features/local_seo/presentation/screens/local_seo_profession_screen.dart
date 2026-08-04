import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/gallery_photo_constants.dart';
import '../../../../core/constants/local_seo.dart';
import '../../../../core/constants/profession_catalog.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/seo/web_seo_meta.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/company.dart';
import '../../../../shared/widgets/async_value_widget.dart';
import '../../../../shared/widgets/company_card_deck.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/savable_company_card.dart';

/// Landing SEO: `/candeleda/fontanero`, etc.
class LocalSeoProfessionScreen extends ConsumerStatefulWidget {
  const LocalSeoProfessionScreen({
    super.key,
    required this.location,
    required this.profession,
  });

  final LocalSeoLocation location;
  final ProfessionItem profession;

  @override
  ConsumerState<LocalSeoProfessionScreen> createState() =>
      _LocalSeoProfessionScreenState();
}

class _LocalSeoProfessionScreenState
    extends ConsumerState<LocalSeoProfessionScreen> {
  @override
  void initState() {
    super.initState();
    _applyMeta();
  }

  @override
  void didUpdateWidget(covariant LocalSeoProfessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.slug != widget.location.slug ||
        oldWidget.profession.name != widget.profession.name) {
      _applyMeta();
    }
  }

  void _applyMeta() {
    final loc = widget.location;
    final name = widget.profession.name;
    applyWebSeoMeta(
      title: LocalSeo.professionTitle(loc, name),
      description: LocalSeo.professionDescription(loc, name),
      canonicalPath: LocalSeo.professionPath(loc, name),
    );
  }

  void _goHub() => context.go(LocalSeo.hubPath(widget.location));

  @override
  Widget build(BuildContext context) {
    final loc = widget.location;
    final profession = widget.profession;
    final params = ProfessionalSearchParams(
      profession: profession.name,
      categoryId: profession.categoryId,
      city: loc.name,
      limit: 24,
    );
    final resultsAsync = ref.watch(professionalsProvider(params));
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final otherCities = LocalSeo.locations
        .where((l) => l.slug != loc.slug)
        .toList(growable: false);
    final related = ProfessionCatalog.allProfessions
        .where((p) => p.categoryId == profession.categoryId)
        .where((p) => p.name != profession.name)
        .take(6)
        .toList();

    return Scaffold(
      primary: false,
      appBar: AppBar(
        title: Text(profession.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver a ${loc.name}',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              _goHub();
            }
          },
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(professionalsProvider(params));
          await ref.read(professionalsProvider(params).future);
        },
        child: ResponsiveContent(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final deckHeight =
                  GalleryPhotoConstants.deckContentHeightForViewport(
                constraints.maxHeight,
                pinnedHeaderHeight: 0,
              );

              return ListView(
                physics: GalleryPhotoConstants.mobileOuterScrollPhysics,
                padding: EdgeInsets.fromLTRB(
                  0,
                  isDesktop ? 12 : 8,
                  0,
                  24 +
                      MediaQuery.paddingOf(context).bottom +
                      (isDesktop ? 24 : kBottomNavigationBarHeight),
                ),
                children: [
                  InkWell(
                    onTap: _goHub,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppTheme.primary.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            loc.name,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            '  ·  oficios',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocalSeo.professionH1(loc, profession.name),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          LocalSeo.professionIntro(loc, profession.name),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                    height: 1.4,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AsyncValueWidget<List<Company>>(
                    value: resultsAsync,
                    loadingMessage: 'Buscando en ${loc.name}...',
                    empty: _EmptyBlock(
                      message: LocalSeo.emptyProfessionMessage(
                        loc,
                        profession.name,
                      ),
                      onPublish: () =>
                          context.push(AppRoutes.professionalRegister),
                    ),
                    data: (results) {
                      if (results.isEmpty) {
                        return _EmptyBlock(
                          message: LocalSeo.emptyProfessionMessage(
                            loc,
                            profession.name,
                          ),
                          onPublish: () =>
                              context.push(AppRoutes.professionalRegister),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            results.length == 1
                                ? '1 profesional cerca'
                                : '${results.length} profesionales cerca',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          if (isDesktop)
                            _DesktopResultsGrid(
                              results: results,
                              highlightProfession: profession.name,
                            )
                          else
                            SizedBox(
                              height: deckHeight.clamp(320.0, 520.0),
                              child: CompanyCardDeck(
                                companies: results,
                                height: deckHeight.clamp(320.0, 520.0),
                                highlightProfession: profession.name,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: PremiumButton(
                      label: 'Soy ${profession.name} · Publicar gratis',
                      onPressed: () =>
                          context.push(AppRoutes.professionalRegister),
                    ),
                  ),
                  if (related.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      'También en ${loc.name}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Otros oficios que suele buscar la gente aquí.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in related)
                          ActionChip(
                            label: Text(p.name),
                            onPressed: () => context.go(
                              LocalSeo.professionPath(loc, p.name),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                  Text(
                    'Cerca de ${loc.name}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mismo oficio en pueblos vecinos de ${loc.regionLabel}.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final other in otherCities)
                        OutlinedButton(
                          onPressed: () => context.go(
                            LocalSeo.professionPath(other, profession.name),
                          ),
                          child: Text(other.name),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopResultsGrid extends StatelessWidget {
  const _DesktopResultsGrid({
    required this.results,
    required this.highlightProfession,
  });

  final List<Company> results;
  final String highlightProfession;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // 2 cols en desktop estrecho; 3 cuando hay hueco de verdad.
        final crossAxisCount = width >= 980 ? 3 : 2;
        final aspect = GalleryPhotoConstants.gridChildAspectRatioFor(
          gridWidth: width,
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          heightSlack: 56,
        );
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: results.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: aspect,
          ),
          itemBuilder: (context, index) {
            return SavableCompanyCard(
              company: results[index],
              highlightProfession: highlightProfession,
              dense: true,
            );
          },
        );
      },
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({
    required this.message,
    required this.onPublish,
  });

  final String message;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A444D)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 16),
            PremiumButton(
              label: 'Publicar mi perfil gratis',
              onPressed: onPublish,
            ),
          ],
        ),
      ),
    );
  }
}
