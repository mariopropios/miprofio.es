import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/gallery_photo_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/storage_image_url.dart';
import 'resilient_network_image.dart';

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
    final displayMaxWidth =
        (size.width * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
              720,
              1280,
            );

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
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.photoUrls.length,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemBuilder: (context, index) {
                    final original = widget.photoUrls[index];
                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: ResilientNetworkImage(
                          originalUrl: original,
                          optimizedUrl: StorageImageUrl.display(
                            original,
                            maxWidth: displayMaxWidth,
                          ),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          memCacheWidth: displayMaxWidth,
                          placeholder: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white70,
                            ),
                          ),
                          error: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 64,
                          ),
                        ),
                      ),
                    );
                  },
                ),

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
class WorkGalleryStrip extends StatefulWidget {
  const WorkGalleryStrip({
    super.key,
    required this.photoUrls,
    this.emptyLabel = 'Sin fotos de trabajos',
    this.lightboxTitle,
  });

  final List<String> photoUrls;
  final String emptyLabel;
  final String? lightboxTitle;

  @override
  State<WorkGalleryStrip> createState() => _WorkGalleryStripState();
}

class _WorkGalleryStripState extends State<WorkGalleryStrip> {
  static const _thumbWidth = GalleryPhotoConstants.thumbWidth;
  static const _thumbHeight = GalleryPhotoConstants.thumbHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefetchThumbnails();
  }

  void _prefetchThumbnails() {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (_thumbWidth * dpr).ceil().clamp(140, 420);
    final cacheHeight = (_thumbHeight * dpr).ceil().clamp(120, 360);

    for (final url in widget.photoUrls.take(6)) {
      final optimized = StorageImageUrl.thumbnail(
        url,
        width: cacheWidth,
        height: cacheHeight,
      );
      precacheImage(
        CachedNetworkImageProvider(
          optimized,
          maxWidth: cacheWidth,
          maxHeight: cacheHeight,
        ),
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.isEmpty) {
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
                widget.emptyLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (_thumbWidth * dpr).ceil().clamp(140, 420);
    final cacheHeight = (_thumbHeight * dpr).ceil().clamp(120, 360);

    return SizedBox(
      height: _thumbHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.photoUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final url = widget.photoUrls[index];
          final optimized = StorageImageUrl.thumbnail(
            url,
            width: cacheWidth,
            height: cacheHeight,
          );

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => PhotoGalleryLightbox.show(
                context,
                photoUrls: widget.photoUrls,
                initialIndex: index,
                title: widget.lightboxTitle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    ResilientNetworkImage(
                      originalUrl: url,
                      optimizedUrl: optimized,
                      width: _thumbWidth,
                      height: _thumbHeight,
                      fit: BoxFit.cover,
                      memCacheWidth: cacheWidth,
                      placeholder: _loadingThumb(),
                      error: _errorThumb(),
                    ),
                    if (widget.photoUrls.length > 1)
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
