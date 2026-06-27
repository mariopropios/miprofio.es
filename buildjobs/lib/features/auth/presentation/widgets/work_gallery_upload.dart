import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/gallery_image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/x_file_preview_image.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/spring_pressable.dart';

/// Área de subida de fotos con borde discontinuo estilo drag-and-drop.
class WorkGalleryUpload extends StatefulWidget {
  const WorkGalleryUpload({
    super.key,
    required this.images,
    required this.onImagesChanged,
    this.maxImages = AppConstants.maxGalleryPhotos,
    this.compact = false,
  });

  final List<XFile> images;
  final ValueChanged<List<XFile>> onImagesChanged;
  final int maxImages;
  final bool compact;

  @override
  State<WorkGalleryUpload> createState() => _WorkGalleryUploadState();
}

class _WorkGalleryUploadState extends State<WorkGalleryUpload> {
  bool _isPicking = false;

  int get _remaining => widget.maxImages - widget.images.length;

  bool get _isMobile => ResponsiveLayout.isMobile(context);

  String get _hintText {
    if (widget.images.length >= widget.maxImages) {
      return 'Has alcanzado el límite de fotos';
    }
    if (_isPicking) return 'Abriendo selector...';
    if (_isMobile) {
      return 'Galería, cámara o archivos de tu móvil';
    }
    return 'Seleccionar imágenes desde tu ordenador';
  }

  Future<void> _openPicker() async {
    if (_remaining <= 0 || _isPicking) return;

    // Iniciar el picker antes de setState: en web el diálogo de archivos
    // requiere el gesto del clic y un rebuild previo lo bloquea.
    final pickFuture = GalleryImagePicker.pickImages(
      context: context,
      maxCount: _remaining,
    );

    setState(() => _isPicking = true);
    try {
      final picked = await pickFuture;
      if (!mounted) return;
      if (picked.isEmpty) return;

      final merged = [...widget.images, ...picked]
          .take(widget.maxImages)
          .toList(growable: false);
      widget.onImagesChanged(merged);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron cargar las fotos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeAt(int index) {
    final next = [...widget.images]..removeAt(index);
    widget.onImagesChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fotos de tus trabajos',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        if (!widget.compact)
          Text(
            'Opcional · Muestra la calidad de tu trabajo (máx. ${widget.maxImages})',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        SizedBox(height: widget.compact ? 8 : 12),
        if (widget.images.isNotEmpty) ...[
          SizedBox(
            height: widget.compact ? 72 : 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _ThumbnailPreview(
                  file: widget.images[index],
                  onRemove: () => _removeAt(index),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        SpringPressable(
          onTap: _remaining <= 0 || _isPicking ? null : _openPicker,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: AppTheme.primary.withValues(alpha: 0.45),
              radius: 12,
            ),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: widget.compact ? 22 : 36,
                horizontal: 20,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1E252B).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (_isPicking)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _isMobile
                          ? Icons.add_photo_alternate_outlined
                          : Icons.folder_open_outlined,
                      size: 36,
                      color: AppTheme.primary.withValues(alpha: 0.85),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _isMobile
                        ? 'Subir fotos de tus trabajos'
                        : 'Seleccionar archivos de imagen',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hintText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ThumbnailPreview extends StatelessWidget {
  const _ThumbnailPreview({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: XFilePreviewImage(
            file: file,
            width: 88,
            height: 88,
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: SpringPressable(
            onTap: onRemove,
            pressedScale: 0.9,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF262E36),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashWidth = 6.0;
    const dashSpace = 5.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
