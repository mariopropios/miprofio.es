import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Visor flotante (dialog) con deslizamiento horizontal entre fotos.
class PhotoGalleryLightbox extends StatefulWidget {
  const PhotoGalleryLightbox({
    super.key,
    required this.photoUrls,
    this.initialIndex = 0,
    this.title,
  });

  final List<String> photoUrls;
  final int initialIndex;
  final String? title;

  static Future<void> show(
    BuildContext context, {
    required List<String> photoUrls,
    int initialIndex = 0,
    String? title,
  }) {
    if (photoUrls.isEmpty) return Future.value();

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => PhotoGalleryLightbox(
        photoUrls: photoUrls,
        initialIndex: initialIndex.clamp(0, photoUrls.length - 1),
        title: title,
      ),
    );
  }

  @override
  State<PhotoGalleryLightbox> createState() => _PhotoGalleryLightboxState();
}

class _PhotoGalleryLightboxState extends State<PhotoGalleryLightbox> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _prev() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _next() {
    if (_currentIndex < widget.photoUrls.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final hasMany = widget.photoUrls.length > 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * 0.08,
        vertical: size.height * 0.08,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 880,
          maxHeight: size.height * 0.82,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: const Color(0xFF111111),
            child: Stack(
              children: [
                // Visor de imagen con paginación
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.photoUrls.length,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: widget.photoUrls[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white70,
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 64,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Flecha izquierda
                if (hasMany && _currentIndex > 0)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _NavArrow(
                        icon: Icons.chevron_left_rounded,
                        onTap: _prev,
                      ),
                    ),
                  ),

                // Flecha derecha
                if (hasMany && _currentIndex < widget.photoUrls.length - 1)
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _NavArrow(
                        icon: Icons.chevron_right_rounded,
                        onTap: _next,
                      ),
                    ),
                  ),

                // Barra superior: cerrar + contador
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      _CircleButton(
                        tooltip: 'Cerrar',
                        icon: Icons.close,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      if (hasMany)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.photoUrls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Título en la parte inferior
                if (widget.title != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Text(
                      widget.title!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
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

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Miniaturas horizontales de la galería; al pulsar abre el visor.
class WorkGalleryStrip extends StatelessWidget {
  const WorkGalleryStrip({
    super.key,
    required this.photoUrls,
    this.emptyLabel = 'Sin fotos de trabajos',
    this.lightboxTitle,
  });

  final List<String> photoUrls;
  final String emptyLabel;
  final String? lightboxTitle;

  static const _thumbWidth = 140.0;
  static const _thumbHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    if (photoUrls.isEmpty) {
      return Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 4),
              Text(
                emptyLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: _thumbHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photoUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final url = photoUrls[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => PhotoGalleryLightbox.show(
                context,
                photoUrls: photoUrls,
                initialIndex: index,
                title: lightboxTitle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: url,
                      width: _thumbWidth,
                      height: _thumbHeight,
                      fit: BoxFit.cover,
                      memCacheWidth: 280,
                      errorWidget: (_, __, ___) => _errorThumb(),
                      placeholder: (_, __) => _loadingThumb(),
                    ),
                    if (photoUrls.length > 1)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Icon(
                          Icons.zoom_out_map_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _loadingThumb() {
    return Container(
      width: _thumbWidth,
      height: _thumbHeight,
      color: AppTheme.surfaceElevated,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _errorThumb() {
    return Container(
      width: _thumbWidth,
      height: _thumbHeight,
      color: AppTheme.surfaceElevated,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
