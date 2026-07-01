import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/gallery_photo_constants.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../models/company.dart';
import 'savable_company_card.dart';

/// Rueda de cartas estilo tragaperras para mostrar [companies] en móvil/tablet.
/// Desplazamiento libre en el eje Y con efecto de tambor sutil.
class CompanyCardDeck extends StatefulWidget {
  const CompanyCardDeck({
    super.key,
    required this.companies,
    this.height = 380,
    this.highlightProfession,
  });

  final List<Company> companies;
  /// Altura del tambor de cartas (más alta en búsqueda móvil al desplazar filtros).
  final double height;
  /// Oficio activo en el filtro de búsqueda para reordenar/resaltar tags en las cartas.
  final String? highlightProfession;

  @override
  State<CompanyCardDeck> createState() => _CompanyCardDeckState();
}

class _CompanyCardDeckState extends State<CompanyCardDeck> {
  late final ScrollController _ctrl;
  late final ValueNotifier<double> _offsetNotifier;

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController();
    _offsetNotifier = ValueNotifier(0);
    _ctrl.addListener(() => _offsetNotifier.value = _ctrl.offset);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _offsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.companies.length;
    if (count == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 8.0;
        final availableWidth = constraints.maxWidth - horizontalPadding;
        final cardWidth =
            GalleryPhotoConstants.deckCardWidth(availableWidth);
        final cardHeight =
            GalleryPhotoConstants.deckEstimatedCardHeight(cardWidth);
        final itemExtent = GalleryPhotoConstants.deckItemExtent(
          constraints.maxWidth,
        );
        final viewportHeight = widget.height;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                height: viewportHeight,
                child: Stack(
                  children: [
                    ListWheelScrollView.useDelegate(
                      controller: _ctrl,
                      itemExtent: itemExtent,
                      physics: const ClampingScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      perspective: 0.0012,
                      squeeze: 0.96,
                      useMagnifier: false,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: count,
                        builder: (context, index) {
                          final company = widget.companies[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            child: Center(
                              child: SizedBox(
                                width: cardWidth,
                                height: cardHeight,
                                child: RepaintBoundary(
                                  child: SavableCompanyCard(
                                    company: company,
                                    dense: true,
                                    highlightProfession:
                                        widget.highlightProfession,
                                    onTap: () => context.push(
                                      AppRoutes.companyDetailPath(company.id),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Degradado superior
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 48,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.scaffoldBackground,
                                AppTheme.scaffoldBackground.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Degradado inferior
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 48,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppTheme.scaffoldBackground,
                                AppTheme.scaffoldBackground.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (count > 1)
              ValueListenableBuilder<double>(
                valueListenable: _offsetNotifier,
                builder: (context, offset, _) {
                  final pos =
                      (offset / itemExtent).clamp(0.0, (count - 1).toDouble());
                  return Padding(
                    padding: const EdgeInsets.only(right: 16, left: 12),
                    child: SizedBox(
                      height: count * 14.0,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Container(
                            width: 4,
                            height: count * 14.0,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 60),
                            curve: Curves.linear,
                            top: count > 1
                                ? pos / (count - 1) * (count * 14.0 - 22)
                                : 0,
                            child: Container(
                              width: 4,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
