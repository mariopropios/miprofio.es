import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
  });

  final Company company;
  final VoidCallback? onTap;

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

    // Usamos HoverLiftCard sin onTap para el wrapper visual (hover/sombra).
    // El tap de navegación solo se pone en la sección de info para que los
    // botones de flecha del carrusel no disparen navegación accidentalmente.
    return HoverLiftCard(
      onTap: null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight.isFinite) {
            return _BoundedCardLayout(
              company: company,
              photos: photos,
              onTap: onTap,
            );
          }
          return _UnboundedCardLayout(
            company: company,
            photos: photos,
            onTap: onTap,
          );
        },
      ),
    );
  }

  static Widget _placeholder() {
    return Container(
      color: AppTheme.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.construction,
          size: 44,
          color: AppTheme.textSecondary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  static Widget _infoSection(
    BuildContext context,
    Company company,
    VoidCallback? onTap,
  ) {
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
          professions: company.professions.isNotEmpty
              ? company.professions
              : [company.profession],
          maxVisible: 2,
          compact: true,
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
  const _PhotoCarousel({required this.photos, this.onTap});

  final List<String> photos;
  final VoidCallback? onTap;

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

  Widget _buildImage(String url, int index) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: _PhotoCarousel._imageCacheWidth,
      maxWidthDiskCache: _PhotoCarousel._imageCacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      errorWidget: (_, __, ___) => CompanyCard._placeholder(),
      placeholder: (_, __) => Container(
        color: AppTheme.surfaceElevated,
        alignment: Alignment.center,
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

    if (photos.isEmpty) return CompanyCard._placeholder();

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Imágenes deslizables ────────────────────────────────────────────
        GestureDetector(
          onTap: widget.onTap,
          child: photos.length == 1
              ? _buildImage(photos[0], 0)
              : PageView.builder(
                  controller: _ctrl,
                  physics: const _SnapPagePhysics(),
                  onPageChanged: (i) => setState(() => _current = i),
                  itemCount: photos.length,
                  itemBuilder: (_, i) => _buildImage(photos[i], i),
                ),
        ),

        // ── Flecha izquierda ────────────────────────────────────────────────
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

        // ── Flecha derecha ──────────────────────────────────────────────────
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

        // ── Indicador de puntos ─────────────────────────────────────────────
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

// ── Physics rápidas para el PageView del carrusel ─────────────────────────────
// Hereda de PageScrollPhysics (snap) pero reduce el umbral de velocidad para
// que con un gesto corto ya se pase a la siguiente foto.

class _SnapPagePhysics extends PageScrollPhysics {
  const _SnapPagePhysics() : super(parent: const ClampingScrollPhysics());

  @override
  _SnapPagePhysics applyTo(ScrollPhysics? ancestor) =>
      const _SnapPagePhysics();

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 80,
        stiffness: 100,
        damping: 1,
      );
}

// ── Layouts ────────────────────────────────────────────────────────────────────

class _BoundedCardLayout extends StatelessWidget {
  const _BoundedCardLayout({
    required this.company,
    required this.photos,
    this.onTap,
  });

  final Company company;
  final List<String> photos;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: ClipRect(
            child: _PhotoCarousel(photos: photos, onTap: onTap),
          ),
        ),
        Expanded(
          flex: 10,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: CompanyCard._infoSection(context, company, onTap),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnboundedCardLayout extends StatelessWidget {
  const _UnboundedCardLayout({
    required this.company,
    required this.photos,
    this.onTap,
  });

  final Company company;
  final List<String> photos;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 160,
          width: double.infinity,
          child: ClipRect(
            child: _PhotoCarousel(photos: photos, onTap: onTap),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: CompanyCard._infoSection(context, company, onTap),
        ),
      ],
    );
  }
}
