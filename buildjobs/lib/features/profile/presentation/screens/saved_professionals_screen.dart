import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/gallery_photo_constants.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/professional.dart';
import '../../../../shared/widgets/async_value_widget.dart';
import '../../../../shared/widgets/company_card_deck.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/save_professional_button.dart';
import '../../../../shared/widgets/savable_company_card.dart';
import '../../../saved/providers/saved_professional_providers.dart';

class SavedProfessionalsScreen extends ConsumerWidget {
  const SavedProfessionalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedProfessionalsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom + 24;
    final useDeck = ResponsiveLayout.isMobile(context);

    Future<void> refresh() async {
      ref.invalidate(savedProfessionalsProvider);
      ref.invalidate(savedProfessionalIdsProvider);
      await ref.read(savedProfessionalsProvider.future);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profesionales guardados'),
      ),
      body: AsyncValueWidget<List<Professional>>(
        value: savedAsync,
        loadingMessage: 'Cargando guardados…',
        empty: _EmptySavedState(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
        ),
        data: (professionals) {
          if (professionals.isEmpty) {
            return _EmptySavedState(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
            );
          }

          return RefreshIndicator(
            onRefresh: refresh,
            child: useDeck
                ? _SavedDeckLayout(professionals: professionals)
                : _SavedGridLayout(
                    professionals: professionals,
                    bottomInset: bottomInset,
                  ),
          );
        },
      ),
    );
  }
}

/// Tambor de tarjetas (mismo flujo adictivo que Inicio / Buscar en móvil).
class _SavedDeckLayout extends StatelessWidget {
  const _SavedDeckLayout({required this.professionals});

  final List<Professional> professionals;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deckHeight = GalleryPhotoConstants.deckContentHeightForViewport(
          constraints.maxHeight,
          pinnedHeaderHeight: 56,
        );

        return CustomScrollView(
          physics: GalleryPhotoConstants.mobileOuterScrollPhysics,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  professionals.length == 1
                      ? '1 profesional guardado'
                      : '${professionals.length} profesionales guardados',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SizedBox(
                    height: deckHeight,
                    child: CompanyCardDeck(
                      companies: professionals,
                      height: deckHeight,
                    ),
                  ),
                  SizedBox(
                    height: GalleryPhotoConstants.deckScrollTailHeight,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Grid en escritorio / tablet ancha.
class _SavedGridLayout extends StatelessWidget {
  const _SavedGridLayout({
    required this.professionals,
    required this.bottomInset,
  });

  final List<Professional> professionals;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveLayout.isDesktop(context) ? 3 : 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = GalleryPhotoConstants.gridChildAspectRatioFor(
          gridWidth: constraints.maxWidth - 32,
          crossAxisCount: crossAxisCount,
        );

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: aspectRatio,
          ),
          itemCount: professionals.length,
          itemBuilder: (context, index) {
            final professional = professionals[index];
            return RepaintBoundary(
              child: SavableCompanyCard(
                company: professional,
                onTap: () => context.push(
                  AppRoutes.companyDetailPath(professional.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptySavedState extends StatelessWidget {
  const _EmptySavedState({required this.padding});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        const SizedBox(height: 48),
        Icon(
          Icons.favorite_border,
          size: 56,
          color: AppTheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 20),
        Text(
          'Aún no has guardado profesionales',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Pulsa el corazón en una ficha de Inicio o Buscar para añadirla aquí.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.search),
          icon: const Icon(Icons.search),
          label: const Text('Buscar profesionales'),
        ),
      ],
    );
  }
}

/// Fila compacta para la vista previa en el perfil.
class SavedProfessionalTile extends StatelessWidget {
  const SavedProfessionalTile({super.key, required this.professional});

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
              SaveProfessionalButton(professionalId: professional.id),
            ],
          ),
        ),
      ),
    );
  }
}
