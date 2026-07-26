import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/widgets/async_value_widget.dart';
import '../../../../shared/widgets/premium_button.dart';
import '../../../companies/presentation/widgets/professional_public_profile_body.dart';
import '../../../saved/providers/saved_professional_providers.dart';
import '../../../../shared/widgets/message_email_notification_card.dart';
import '../../../../shared/widgets/push_notification_setup_card.dart';
import '../../../../shared/widgets/legal_links_row.dart';
import '../../../../shared/widgets/share_professional_button.dart';
import '../widgets/email_verified_welcome_listener.dart';
import '../widgets/saved_professionals_section.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    final Widget content;
    if (user == null) {
      content = const _LoggedOutProfile();
    } else {
      content = _LoggedInProfile(userId: user.id, email: user.email);
    }

    return EmailVerifiedWelcomeListener(child: content);
  }
}

class _LoggedInProfile extends ConsumerWidget {
  const _LoggedInProfile({required this.userId, this.email});

  final String userId;
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewAsync = ref.watch(currentUserProfessionalViewProvider);

    return viewAsync.when(
      loading: () => const Scaffold(
        primary: false,
        appBar: _ProfileAppBar(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        primary: false,
        appBar: _ProfileAppBar(userId: userId),
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
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
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
                      ref.invalidate(currentUserProfessionalViewProvider),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (view) {
        if (view.isProfessional && !view.hasListing) {
          return _IncompleteProfessionalProfile(userId: userId);
        }

        if (view.isProfessional) {
          final bottomInset =
              MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight;
          final companyAsync =
              ref.watch(professionalDetailProvider(view.professionalId));
          final professionalName = companyAsync.maybeWhen(
            data: (c) => c?.name,
            orElse: () => null,
          );
          return Scaffold(
            primary: false,
            appBar: _ProfileAppBar(
              userId: userId,
              isProfessional: true,
              professionalId: view.professionalId,
              professionalName: professionalName,
            ),
            body: ProfessionalPublicProfileBody(
              companyId: view.professionalId,
              bottomPadding: 16 + bottomInset,
              isOwnerView: true,
            ),
          );
        }

        return _ClientProfileView(userId: userId, email: email);
      },
    );
  }
}

class _LoggedOutProfile extends StatelessWidget {
  const _LoggedOutProfile();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: false,
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.person,
                    size: 48,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Inicia sesión para gestionar tu perfil',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Guarda profesionales favoritos y valora reseñas.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: PremiumButton(
                    label: 'Iniciar sesión',
                    onPressed: () => context.push(AppRoutes.login),
                  ),
                ),
                const SizedBox(height: 12),
                PremiumOutlinedButton(
                  label: 'Crear cuenta',
                  onPressed: () => context.push(AppRoutes.register),
                ),
                const SizedBox(height: 28),
                const LegalLinksRow(dense: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _ProfileAppBar({
    this.userId,
    this.isProfessional = false,
    this.professionalId,
    this.professionalName,
  });

  final String? userId;
  final bool isProfessional;
  final String? professionalId;
  final String? professionalName;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      title: Text(isProfessional ? 'Mi perfil público' : 'Mi perfil'),
      actions: [
        if (userId != null) ...[
          if (isProfessional &&
              professionalId != null &&
              professionalId!.isNotEmpty)
            ShareProfessionalButton(
              professionalId: professionalId!,
              professionalName: professionalName,
              offerOwnerPresets: true,
            ),
          IconButton(
            tooltip: 'Editar perfil',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(
              isProfessional
                  ? '${AppRoutes.editProfile}?kind=professional'
                  : AppRoutes.editProfile,
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (!context.mounted) return;
              ref.invalidate(currentProfileProvider);
              ref.invalidate(currentProfessionalProfileProvider);
              ref.invalidate(currentUserProfessionalViewProvider);
              ref.invalidate(savedProfessionalIdsProvider);
              ref.invalidate(savedProfessionalsProvider);
            },
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }
}

class _IncompleteProfessionalProfile extends ConsumerWidget {
  const _IncompleteProfessionalProfile({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      primary: false,
      appBar: _ProfileAppBar(userId: userId, isProfessional: true),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.construction_outlined,
                  size: 56,
                  color: AppTheme.primary.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tu ficha profesional no está publicada',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Completa el registro profesional para que los clientes vean tu perfil público aquí.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                PremiumButton(
                  label: 'Completar registro profesional',
                  onPressed: () =>
                      context.push(AppRoutes.professionalRegister),
                ),
                const SizedBox(height: 28),
                const LegalLinksRow(dense: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientProfileView extends ConsumerWidget {
  const _ClientProfileView({
    required this.userId,
    this.email,
  });

  final String userId;
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      primary: false,
      appBar: _ProfileAppBar(userId: userId),
      body: AsyncValueWidget<UserProfile?>(
        value: profileAsync,
        data: (profile) {
          final displayName =
              profile?.fullName ?? email?.split('@').first ?? 'Usuario';

          final bottomInset =
              MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.15),
                      backgroundImage: profile?.avatarUrl != null
                          ? NetworkImage(profile!.avatarUrl!)
                          : null,
                      child: profile?.avatarUrl == null
                          ? Text(
                              displayName[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 16),
                    const MessageEmailNotificationCard(),
                    const SizedBox(height: 12),
                    const PushNotificationSetupCard(),
                    const SizedBox(height: 16),
                    _StatCard(
                      icon: Icons.rate_review,
                      label: 'Reseñas escritas',
                      value: '${profile?.reviewCount ?? 0}',
                    ),
                    const SizedBox(height: 16),
                    const SavedProfessionalsSection(),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '¿Eres profesional?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Publica tu ficha para que los clientes te encuentren. En Perfil verás cómo te ven ellos.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                          ),
                          const SizedBox(height: 14),
                          PremiumButton(
                            label: 'Publicar perfil profesional',
                            onPressed: () =>
                                context.push(AppRoutes.professionalRegister),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const LegalLinksRow(dense: true),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
