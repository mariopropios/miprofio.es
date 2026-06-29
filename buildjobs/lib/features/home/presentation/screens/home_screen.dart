import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/gallery_photo_constants.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/geo_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/company.dart';
import '../../../../shared/widgets/async_value_widget.dart';
import '../../../../shared/widgets/savable_company_card.dart';
import '../../../../shared/widgets/company_card_deck.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/spring_pressable.dart';
import '../widgets/profession_filter_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredAsync = ref.watch(featuredProfessionalsProvider);
    // Escritorio web: sin logo en AppBar (NavigationRail). iPhone/iPad: con logo.
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final deckHeight = GalleryPhotoConstants.deckViewportHeight(
      MediaQuery.sizeOf(context).height,
    );

    return Scaffold(
      appBar: AppBar(
        // En escritorio el NavigationRail ya muestra el logo; en móvil lo mostramos aquí.
        title: isDesktop
            ? null
            : const Row(
                children: [
                  Icon(Icons.construction, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(AppConstants.appName),
                ],
              ),
        // _AuthActionButton es un Consumer independiente: se reconstruye solo
        // cuando cambia el estado de auth, no cuando cambia featuredAsync.
        actions: const [_AuthActionButton(), SizedBox(width: 12)],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(featuredProfessionalsProvider);
          await ref.read(featuredProfessionalsProvider.future);
        },
        child: ResponsiveContent(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  AppConstants.appTagline,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Descubre, compara y valora profesionales del hogar cerca de ti.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),
                _SearchBar(
                  onTap: () => context.go(AppRoutes.search),
                  onNearMe: (city) => context.go(
                    AppRoutes.searchWith(city: city),
                  ),
                ),
                const SizedBox(height: 32),
                ProfessionFilterSection(
                  onProfessionTap: (name, categoryId) => context.go(
                    AppRoutes.searchWith(
                      profession: name,
                      categoryId: categoryId,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Profesionales destacados',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                AsyncValueWidget<List<Company>>(
                  value: featuredAsync,
                  loadingMessage: 'Cargando profesionales...',
                  empty: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No hay profesionales todavía.\nEjecuta el script SQL en Supabase.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ),
                  ),
                  data: (companies) => ResponsiveLayout.isDesktop(context)
                      ? _CompanyGrid(companies: companies)
                      : SizedBox(
                          height: deckHeight,
                          child: CompanyCardDeck(
                            companies: companies,
                            height: deckHeight,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.onTap, required this.onNearMe});

  final VoidCallback onTap;
  final ValueChanged<String> onNearMe;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  bool _locating = false;
  String? _locError;

  Future<void> _handleNearMe() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final city = await GeoService.detectCity();
      if (mounted) widget.onNearMe(city);
    } on GeoServiceException catch (e) {
      if (mounted) setState(() => _locError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _locError = 'No se pudo obtener la ubicación.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Barra de búsqueda ──────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: SpringPressable(
                onTap: widget.onTap,
                pressedScale: 0.99,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.divider, width: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search,
                          color: AppTheme.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Buscar por nombre, oficio o ciudad...',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Botón "Cerca de mí" ────────────────────────────────────────────
        GestureDetector(
          onTap: _locating ? null : _handleNearMe,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _locating
                  ? AppTheme.primary.withValues(alpha: 0.1)
                  : AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _locating
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : AppTheme.divider,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _locating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: AppTheme.primary,
                        ),
                      )
                    : const Icon(
                        Icons.my_location_rounded,
                        size: 15,
                        color: AppTheme.primary,
                      ),
                const SizedBox(width: 6),
                Text(
                  _locating ? 'Detectando...' : 'Cerca de mí',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _locating
                        ? AppTheme.primary.withValues(alpha: 0.7)
                        : AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Error de geolocalización (si ocurre)
        if (_locError != null) ...[
          const SizedBox(height: 6),
          Text(
            _locError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
        ],
      ],
    );
  }
}

class _CompanyGrid extends StatelessWidget {
  const _CompanyGrid({required this.companies});

  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveLayout.isDesktop(context) ? 3 : 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = GalleryPhotoConstants.gridChildAspectRatioFor(
          gridWidth: constraints.maxWidth,
          crossAxisCount: crossAxisCount,
        );

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: aspectRatio,
          ),
          addAutomaticKeepAlives: false,
          itemCount: companies.length,
          itemBuilder: (context, index) {
            final company = companies[index];
            return RepaintBoundary(
              child: SavableCompanyCard(
                company: company,
                onTap: () =>
                    context.push(AppRoutes.companyDetailPath(company.id)),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Botón de auth aislado para no reconstruir HomeScreen completo ─────────────
// Solo se reconstruye cuando cambia currentUserProvider.

class _AuthActionButton extends ConsumerWidget {
  const _AuthActionButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    void onTap() => context.go(AppRoutes.profile);
    return user == null
        ? _LoginButton(onTap: onTap)
        : _ProfileAvatarButton(onTap: onTap);
  }
}

// ── Botón de perfil cuando el usuario está logueado ────────────────────────────

class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Mi perfil',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withValues(alpha: 0.15),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: AppTheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ── Botón de login cuando el usuario NO está logueado ─────────────────────────

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.5),
          ),
        ),
        child: const Text(
          'Iniciar sesión',
          style: TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
