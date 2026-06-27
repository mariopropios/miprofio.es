import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/professional.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/widgets/async_value_widget.dart';

/// Perfil público de un usuario cliente (desde reseñas, etc.).
class PublicClientProfileScreen extends ConsumerWidget {
  const PublicClientProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(publicUserProfileProvider(userId));
    final savedAsync = ref.watch(publicUserSavedProfessionalsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de usuario'),
      ),
      body: AsyncValueWidget<UserProfile?>(
        value: profileAsync,
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Usuario no encontrado'));
          }

          final displayName =
              profile.fullName?.trim().isNotEmpty == true
                  ? profile.fullName!.trim()
                  : 'Usuario';

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.15),
                      backgroundImage: profile.avatarUrl != null
                          ? CachedNetworkImageProvider(profile.avatarUrl!)
                          : null,
                      child: profile.avatarUrl == null
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
                      textAlign: TextAlign.center,
                    ),
                    if (profile.city != null &&
                        profile.city!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile.city!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _StatCard(
                      icon: Icons.rate_review,
                      label: 'Reseñas escritas',
                      value: '${profile.reviewCount}',
                    ),
                    const SizedBox(height: 28),
                    _SavedSection(savedAsync: savedAsync),
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
            Text(label),
            const Spacer(),
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

class _SavedSection extends StatelessWidget {
  const _SavedSection({required this.savedAsync});

  final AsyncValue<List<Professional>> savedAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Profesionales guardados',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          savedAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const Text(
              'No se pudo cargar la lista de guardados.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            data: (professionals) {
              if (professionals.isEmpty) {
                return Text(
                  'Este usuario aún no ha guardado profesionales.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: professionals.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _PublicSavedTile(professional: professionals[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PublicSavedTile extends StatelessWidget {
  const _PublicSavedTile({required this.professional});

  final Professional professional;

  @override
  Widget build(BuildContext context) {
    final photo = professional.profilePhoto;

    return Material(
      color: AppTheme.scaffoldBackground,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.companyDetailPath(professional.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                backgroundImage: photo != null && photo.isNotEmpty
                    ? CachedNetworkImageProvider(photo)
                    : null,
                child: photo == null || photo.isEmpty
                    ? Text(
                        professional.name.isNotEmpty
                            ? professional.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      professional.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${professional.primaryProfession} · ${professional.city}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
