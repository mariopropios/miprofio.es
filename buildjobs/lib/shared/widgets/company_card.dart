import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/gallery_photo_constants.dart';
import '../../core/theme/app_theme.dart';
import '../models/company.dart';
import 'hover_lift_card.dart';
import 'profession_tags_row.dart';
import 'rating_stars.dart';

class CompanyCard extends StatelessWidget {
  const CompanyCard({
    super.key,
    required this.company,
    this.onTap,
    this.photoOverlay,
    this.savedCountOverride,
    this.highlightProfession,
  });

  final Company company;
  final VoidCallback? onTap;
  final Widget? photoOverlay;
  /// Si se proporciona, reemplaza company.savedCount en la UI (para actualizaciones optimistas).
  final int? savedCountOverride;
  /// Oficio activo en el filtro de búsqueda. Se mueve al principio de la lista
  /// y se resalta visualmente dentro de la tarjeta.
  final String? highlightProfession;

  /// Fotos ordenadas: primero el logo/portada, luego la galería sin duplicados.
  List<String> get _photos {
    final result = <String>[];
    final profile = company.profilePhoto;
    if (profile != null && profile.isNotEmpty) result.add(profile);
    for (final p in company.galleryPhotos) {
      if (p.isNotEmpty && !result.contains(p)) result.add(p);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;

    // SelectionContainer.disabled evita que el navegador web active la
    // selección de texto (pantalla azul) al pulsar el carrusel o sus flechas.
    return SelectionContainer.disabled(
      child: HoverLiftCard(
        onTap: null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: GalleryPhotoConstants.aspectRatio,
              child: ClipRect(
                child: _PhotoCarousel(
                  photos: photos,
                  onTap: onTap,
                  overlay: photoOverlay,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: _infoSection(
                context,
                company,
                onTap,
                savedCountOverride: savedCountOverride,
                highlightProfession: highlightProfession,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _placeholder({Widget? child}) {
    return Container(
      color: AppTheme.surfaceElevated,
      child: Center(
        child: child ??
            Icon(
              Icons.construction,
              size: 44,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
      ),
    );
  }

  /// Mueve [highlight] al primer lugar de [professions] si está presente.
  static List<String> _sortedProfessions(
    List<String> professions,
    String? highlight,
  ) {
    if (highlight == null || professions.length <= 1) return professions;
    final lower = highlight.toLowerCase();
    final idx = professions.indexWhere((p) => p.toLowerCase() == lower);
    if (idx <= 0) return professions;
    final sorted = List<String>.from(professions);
    sorted.insert(0, sorted.removeAt(idx));
    return sorted;
  }

  static Widget _infoSection(
    BuildContext context,
    Company company,
    VoidCallback? onTap, {
    int? savedCountOverride,
    String? highlightProfession,
  }) {
    final savedCount = savedCountOverride ?? company.savedCount;
    final rawProfessions = company.professions.isNotEmpty
        ? company.professions
        : [company.profession];
    final sortedProfessions =
        _sortedProfessions(rawProfessions, highlightProfession);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          company.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        ProfessionTagsRow(
          professions: sortedProfessions,
          maxVisible: 2,
          compact: true,
          highlight: highlightProfession,
        ),
        const SizedBox(height: 4),
        Text(
          company.city,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (company.travelRadiusLabel.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  company.travelRadiusLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            RatingStars(rating: company.rating, size: 16),
            const SizedBox(width: 8),
            Text(
              '(${company.reviewCount})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
            if (savedCount > 0) ...[
              const SizedBox(width: 10),
              const Icon(
                Icons.favorite_rounded,
                size: 12,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 3),
              Text(
                '$savedCount',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
              ),
            ],
          ],
        ),
      ],
    );

    if (onTap == null) return content;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

// ── Carrusel de fotos ──────────────────────────────────────────────────────────

class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({
    required this.photos,
    this.onTap,
    this.overlay,
  });

  final List<String> photos;
  final VoidCallback? onTap;
  final Widget? overlay;

  static const _imageCacheWidth = 480;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  late final PageController _ctrl;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: _PhotoCarousel._imageCacheWidth,
      maxWidthDiskCache: _PhotoCarousel._imageCacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      errorWidget: (_, __, ___) => CompanyCard._placeholder(),
      placeholder: (_, __) => CompanyCard._placeholder(
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  void _go(int index) {
    _ctrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    if (photos.isEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: MouseRegion(
              cursor: widget.onTap != null
                  ? SystemMouseCursors.click
                  : MouseCursor.defer,
              child: CompanyCard._placeholder(),
            ),
          ),
          if (widget.overlay != null)
            Positioned(
              top: 8,
              right: 8,
              child: widget.overlay!,
            ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: photos.length == 1
              ? _buildImage(photos[0])
              : PageView.builder(
                  controller: _ctrl,
                  physics: const PageScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  onPageChanged: (i) => setState(() => _current = i),
                  itemCount: photos.length,
                  itemBuilder: (_, i) => _buildImage(photos[i]),
                ),
        ),

        if (photos.length > 1 && _current > 0)
          Positioned(
            left: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ArrowButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _go(_current - 1),
              ),
            ),
          ),

        if (photos.length > 1 && _current < photos.length - 1)
          Positioned(
            right: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: _ArrowButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _go(_current + 1),
              ),
            ),
          ),

        if (photos.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                photos.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _current ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _current
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),

        if (widget.overlay != null)
          Positioned(
            top: 8,
            right: 8,
            child: widget.overlay!,
          ),
      ],
    );
  }
}

// ── Botón de flecha ────────────────────────────────────────────────────────────

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
