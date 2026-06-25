import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/company.dart';
import '../../../../shared/widgets/async_value_widget.dart';
import '../../../../shared/widgets/company_card.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/spring_pressable.dart';
import '../widgets/profession_filter_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredAsync = ref.watch(featuredProfessionalsProvider);
    final user = ref.watch(currentUserProvider);

    final isDesktop = !ResponsiveLayout.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        // En escritorio el NavigationRail ya muestra el logo; en móvil lo mostramos aquí.
        title: isDesktop
            ? null
            : Row(
                children: [
                  Icon(Icons.construction, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(AppConstants.appName),
                ],
              ),
        actions: [
          if (user == null)
            _LoginButton(onTap: () => context.go(AppRoutes.profile))
          else
            _ProfileAvatarButton(onTap: () => context.go(AppRoutes.profile)),
          const SizedBox(width: 12),
        ],
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
                  'Descubre, compara y valora profesionales de la construcción cerca de ti.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 24),
                _SearchBar(
                  onTap: () => context.go(AppRoutes.search),
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
                  data: (companies) => ResponsiveLayout(
                    mobile: Column(
                      children: companies
                          .map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: CompanyCard(
                                  company: c,
                                  onTap: () => context.push(
                                    AppRoutes.companyDetailPath(c.id),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    tablet: _CompanyGrid(companies: companies),
                    desktop: _CompanyGrid(companies: companies),
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

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SpringPressable(
      onTap: onTap,
      pressedScale: 0.99,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.divider, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(
              'Buscar por nombre, oficio o ciudad...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompanyGrid extends StatelessWidget {
  const _CompanyGrid({required this.companies});

  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveLayout.isDesktop(context) ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: ResponsiveLayout.isDesktop(context) ? 0.78 : 0.82,
      ),
      addAutomaticKeepAlives: false,
      itemCount: companies.length,
      itemBuilder: (context, index) {
        final company = companies[index];
        return CompanyCard(
          company: company,
          onTap: () => context.push(AppRoutes.companyDetailPath(company.id)),
        );
      },
    );
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
