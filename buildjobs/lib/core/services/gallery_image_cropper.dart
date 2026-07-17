import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../utils/crop_preview_prepare.dart';
import '../utils/x_file_bytes_reader.dart';
import '../../shared/widgets/gallery_photo_crop_screen.dart';

/// Recorta fotos de trabajos al marco del perfil cuando hace falta.
class GalleryImageCropper {
  GalleryImageCropper._();

  /// Devuelve `true` si conviene pedir al usuario que encuadre la foto.
  static bool needsCrop(int width, int height) =>
      CropPreviewPrepare.needsCrop(width, height);

  /// Procesa cada imagen: abre el encuadre si la proporción no coincide.
  static Future<List<XFile>> cropForGallery({
    required BuildContext context,
    required List<XFile> files,
    bool forceCrop = false,
  }) async {
    if (files.isEmpty) return const [];

    final cropped = <XFile>[];
    final total = files.length;

    for (var i = 0; i < files.length; i++) {
      if (!context.mounted) break;

      final file = files[i];
      final bytes = await readXFileBytes(file);
      if (bytes.isEmpty) continue;

      // Check barato por cabeceras JPEG/PNG/WebP (sin decode completo).
      final openCropper = CropPreviewPrepare.shouldOpenCropper(
        bytes,
        forceCrop: forceCrop,
      );

      if (!openCropper) {
        cropped.add(file);
        continue;
      }

      if (!context.mounted) break;

      final previewBytes = await _preparePreviewWithFeedback(context, bytes);
      if (previewBytes == null || !context.mounted) break;

      final result = await GalleryPhotoCropScreen.show(
        context,
        imageBytes: previewBytes,
        originalName: file.name.isNotEmpty ? file.name : 'photo.jpg',
        photoIndex: total > 1 ? i + 1 : null,
        photoCount: total > 1 ? total : null,
      );

      if (!context.mounted) break;
      if (result != null) {
        cropped.add(result);
      }
    }

    return cropped;
  }

  /// Downscale en isolate; diálogo breve solo si tarda >180 ms.
  static Future<Uint8List?> _preparePreviewWithFeedback(
    BuildContext context,
    Uint8List bytes,
  ) async {
    var completed = false;
    final prepareFuture = CropPreviewPrepare.preparePreviewBytes(bytes).then((
      value,
    ) {
      completed = true;
      return value;
    });

    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!context.mounted) return null;

    var dialogShown = false;
    if (!completed) {
      dialogShown = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              color: AppTheme.surface,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Preparando foto…',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    try {
      final preview = await prepareFuture;
      if (dialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return preview;
    } catch (_) {
      if (dialogShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return bytes;
    }
  }
}
