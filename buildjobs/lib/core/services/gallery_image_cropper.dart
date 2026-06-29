import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../constants/gallery_photo_constants.dart';
import '../utils/x_file_bytes_reader.dart';
import '../../shared/widgets/gallery_photo_crop_screen.dart';

/// Recorta fotos de trabajos al marco del perfil cuando hace falta.
class GalleryImageCropper {
  GalleryImageCropper._();

  /// Tolerancia relativa entre la proporción de la imagen y la del perfil.
  static const _aspectTolerance = 0.05;

  /// Devuelve `true` si conviene pedir al usuario que encuadre la foto.
  static bool needsCrop(int width, int height) {
    if (width <= 0 || height <= 0) return true;

    final imageAspect = width / height;
    final target = GalleryPhotoConstants.aspectRatio;
    return (imageAspect - target).abs() / target > _aspectTolerance;
  }

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

      final decoded = img.decodeImage(bytes);
      final shouldCrop = forceCrop ||
          decoded == null ||
          needsCrop(decoded.width, decoded.height);

      if (!shouldCrop) {
        cropped.add(file);
        continue;
      }

      if (!context.mounted) break;

      final result = await GalleryPhotoCropScreen.show(
        context,
        imageBytes: bytes,
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
}
