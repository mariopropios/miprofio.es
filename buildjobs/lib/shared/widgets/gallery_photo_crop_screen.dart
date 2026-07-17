import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/gallery_photo_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/premium_button.dart';

/// Pantalla para encuadrar una foto con el marco fijo del perfil.
class GalleryPhotoCropScreen extends StatefulWidget {
  const GalleryPhotoCropScreen({
    super.key,
    required this.imageBytes,
    required this.originalName,
    this.photoIndex,
    this.photoCount,
  });

  final Uint8List imageBytes;
  final String originalName;
  final int? photoIndex;
  final int? photoCount;

  static Future<XFile?> show(
    BuildContext context, {
    required Uint8List imageBytes,
    required String originalName,
    int? photoIndex,
    int? photoCount,
  }) {
    return Navigator.of(context).push<XFile?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GalleryPhotoCropScreen(
          imageBytes: imageBytes,
          originalName: originalName,
          photoIndex: photoIndex,
          photoCount: photoCount,
        ),
      ),
    );
  }

  @override
  State<GalleryPhotoCropScreen> createState() => _GalleryPhotoCropScreenState();
}

class _GalleryPhotoCropScreenState extends State<GalleryPhotoCropScreen> {
  final _cropController = CropController();
  bool _isCropping = false;
  bool _isReady = false;

  String get _counterLabel {
    final index = widget.photoIndex;
    final count = widget.photoCount;
    if (index == null || count == null || count <= 1) return '';
    return 'Foto $index de $count';
  }

  void _onConfirm() {
    if (_isCropping || !_isReady) return;
    setState(() => _isCropping = true);
    _cropController.crop();
  }

  void _onCropped(CropResult result) {
    if (!mounted) return;

    switch (result) {
      case CropSuccess(:final croppedImage):
        final name = _croppedFileName(widget.originalName);
        Navigator.of(context).pop(
          XFile.fromData(
            croppedImage,
            name: name,
            mimeType: 'image/jpeg',
          ),
        );
      case CropFailure(:final cause):
        setState(() => _isCropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo recortar la foto: $cause')),
        );
    }
  }

  String _croppedFileName(String original) {
    final base = original.contains('.')
        ? original.substring(0, original.lastIndexOf('.'))
        : original;
    return '${base}_crop.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final counter = _counterLabel;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajustar encuadre',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (counter.isNotEmpty)
              Text(
                counter,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Arrastra y haz zoom para elegir la parte de la foto que se verá en tu perfil.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Crop(
                    image: widget.imageBytes,
                    controller: _cropController,
                    aspectRatio: GalleryPhotoConstants.aspectRatio,
                    interactive: true,
                    fixCropRect: true,
                    baseColor: Colors.black,
                    maskColor: Colors.black.withValues(alpha: 0.62),
                    radius: 10,
                    onCropped: _onCropped,
                    onStatusChanged: (status) {
                      if (!mounted) return;
                      if (status == CropStatus.ready && !_isReady) {
                        setState(() => _isReady = true);
                      }
                    },
                    initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                      size: 0.92,
                      aspectRatio: GalleryPhotoConstants.aspectRatio,
                    ),
                    progressIndicator: const SizedBox.shrink(),
                    cornerDotBuilder: (size, edge) => Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  if (!_isReady)
                    const ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.primary,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Cargando encuadre…',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_isCropping)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.primary,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Procesando…',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PremiumButton(
                    label: _isCropping ? 'Procesando…' : 'Usar esta parte',
                    isLoading: _isCropping,
                    onPressed: _isReady && !_isCropping ? _onConfirm : null,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        _isCropping ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
