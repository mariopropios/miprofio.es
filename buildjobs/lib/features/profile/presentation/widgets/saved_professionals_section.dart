import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../saved/providers/saved_professional_providers.dart';
import '../screens/saved_professionals_screen.dart';

class SavedProfessionalsSection extends ConsumerWidget {
  const SavedProfessionalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedProfessionalsProvider);
    final idsAsync = ref.watch(savedProfessionalIdsProvider);

    final count = savedAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => idsAsync.maybeWhen(data: (ids) => ids.length, orElse: () => null),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SavedHeaderCard(
          count: count,
          onTap: () => context.push(AppRoutes.savedProfessionals),
        ),
        savedAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () {
                ref.invalidate(savedProfessionalsProvider);
                ref.invalidate(savedProfessionalIdsProvider);
              },
              child: const Text('Reintentar cargar guardados'),
            ),
          ),
          data: (professionals) {
            if (professionals.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Pulsa el corazón en una ficha para guardar profesionales que te interesen.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                ),
              );
            }

            final preview = professionals.take(3).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                ...preview.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SavedProfessionalTile(professional: p),
                  ),
                ),
                if (professionals.length > 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          context.push(AppRoutes.savedProfessionals),
                      child: Text(
                        'Ver los ${professionals.length} guardados',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SavedHeaderCard extends StatelessWidget {
  const _SavedHeaderCard({
    required this.count,
    required this.onTap,
  });

  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.redAccent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Profesionales guardados'),
              ),
              if (count == null)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '$count',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
