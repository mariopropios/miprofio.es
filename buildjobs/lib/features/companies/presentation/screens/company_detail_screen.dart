import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/professional.dart';
import '../../../../shared/widgets/rating_stars.dart';
import '../../../../shared/widgets/save_professional_button.dart';
import '../../../../shared/widgets/share_professional_button.dart';
import '../widgets/professional_public_profile_body.dart';

class CompanyDetailScreen extends ConsumerWidget {
  const CompanyDetailScreen({super.key, required this.companyId});

  final String companyId;

  void _goBack(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(professionalDetailProvider(companyId));
    final user = ref.watch(currentUserProvider);
    final isAuthenticated = user != null;
    final viewAsync = ref.watch(currentUserProfessionalViewProvider);
    final isOwnListing = viewAsync.maybeWhen(
      data: (view) =>
          view.isProfessional &&
          view.hasListing &&
          view.professionalId == companyId,
      orElse: () => false,
    );

    return companyAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _goBack(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo cargar el perfil',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Comprueba tu conexión e inténtalo de nuevo.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  onPressed: () =>
                      ref.invalidate(professionalDetailProvider(companyId)),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (company) {
        if (company == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _goBack(context),
              ),
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_off_outlined,
                        size: 56, color: AppTheme.textSecondary),
                    SizedBox(height: 16),
                    Text(
                      'Este profesional ya no está disponible',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'La cuenta se eliminó o la ficha dejó de estar activa.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ── Muro de registro para usuarios anónimos ──────────────────────────
        if (!isAuthenticated) {
          return _RegisterWall(
            company: company,
            onBack: () => _goBack(context),
            companyId: companyId,
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(company.name),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _goBack(context),
            ),
            actions: [
              ShareProfessionalButton(
                professionalId: companyId,
                professionalName: company.name,
                offerOwnerPresets: isOwnListing,
              ),
              if (!isOwnListing)
                SaveProfessionalButton(professionalId: companyId),
            ],
          ),
          // Los profesionales no pueden reseñarse a sí mismos
          floatingActionButton: isOwnListing
              ? null
              : ProfessionalWriteReviewFab(companyId: companyId),
          body: ProfessionalPublicProfileBody(companyId: companyId),
        );
      },
    );
  }
}

// ── Muro de registro ──────────────────────────────────────────────────────────

class _RegisterWall extends StatelessWidget {
  const _RegisterWall({
    required this.company,
    required this.onBack,
    required this.companyId,
  });

  final Professional company;
  final VoidCallback onBack;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final photo = company.profilePhoto;
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 600;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.35),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 48 : 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Avatar ─────────────────────────────────────────
                  _ProfessionalAvatar(photo: photo, name: company.name),
                  const SizedBox(height: 20),

                  // ── Nombre y oficio ────────────────────────────────
                  Text(
                    company.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      company.profession,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RatingStars(rating: company.rating, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${company.rating.toStringAsFixed(1)}  ·  ${company.city}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // ── Tarjeta de registro ────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppTheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Crea una cuenta para ver el perfil completo',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Con tu cuenta en ${AppConstants.appName} puedes ver el perfil completo, leer reseñas, ver la galería de trabajos y enviar mensajes directamente al profesional.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Botón principal: crear cuenta
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => context.push(
                              '${AppRoutes.register}?redirect=${AppRoutes.companyDetailPath(companyId)}',
                            ),
                            icon: const Icon(Icons.person_add_outlined),
                            label: const Text('Crear cuenta gratis'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Botón secundario: iniciar sesión
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(
                              '${AppRoutes.login}?redirect=${AppRoutes.companyDetailPath(companyId)}',
                            ),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Ya tengo cuenta'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              foregroundColor: AppTheme.textPrimary,
                              side: const BorderSide(
                                  color: AppTheme.divider),
                              textStyle: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Avatar del profesional ─────────────────────────────────────────────────────

class _ProfessionalAvatar extends StatelessWidget {
  const _ProfessionalAvatar({required this.photo, required this.name});

  final String? photo;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.primary, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: photo != null && photo!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photo!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _initials(),
              )
            : _initials(),
      ),
    );
  }

  Widget _initials() {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      color: AppTheme.surfaceElevated,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }
}
