import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../constants/gallery_photo_constants.dart';
import 'image_bounds.dart';

/// Prepara bytes ligeros para la UI de «Ajustar encuadre».
class CropPreviewPrepare {
  CropPreviewPrepare._();

  /// Lado largo del preview del cropper (suficiente para ficha; rápido en web).
  static const previewMaxSide = 1280;
  static const previewJpegQuality = 82;

  /// Por debajo de esto y con lado corto, no merece downscale.
  static const _skipBytesUnder = 350 * 1024;

  static bool needsCrop(int width, int height) {
    if (width <= 0 || height <= 0) return true;
    final imageAspect = width / height;
    final target = GalleryPhotoConstants.aspectRatio;
    return (imageAspect - target).abs() / target > 0.05;
  }

  /// true si hay que abrir el cropper (cabeceras o force).
  static bool shouldOpenCropper(
    Uint8List bytes, {
    bool forceCrop = false,
  }) {
    if (forceCrop) return true;
    final bounds = readImageBounds(bytes);
    if (bounds == null) return true; // HEIC / desconocido → crop/seguro
    return needsCrop(bounds.width, bounds.height);
  }

  static bool _alreadyLightEnough(Uint8List input) {
    final bounds = readImageBounds(input);
    if (bounds != null &&
        bounds.width <= previewMaxSide &&
        bounds.height <= previewMaxSide) {
      return true;
    }
    // Sin cabeceras: solo omitir si es muy pequeña en bytes.
    if (bounds == null && input.length <= _skipBytesUnder) {
      return true;
    }
    return false;
  }

  static Future<Uint8List> preparePreviewBytes(Uint8List input) async {
    if (_alreadyLightEnough(input)) {
      return input;
    }

    try {
      return await compute(_preparePreviewInIsolate, input)
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      debugPrint('[CropPreview] compute falló, fallback sync: $e');
      try {
        return _preparePreviewInIsolate(input);
      } catch (_) {
        return input;
      }
    }
  }
}

/// Top-level para [compute] / web worker.
Uint8List _preparePreviewInIsolate(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return input;

  var image = decoded;
  const maxSide = CropPreviewPrepare.previewMaxSide;
  if (image.width > maxSide || image.height > maxSide) {
    if (image.width >= image.height) {
      image = img.copyResize(
        image,
        width: maxSide,
        interpolation: img.Interpolation.linear,
      );
    } else {
      image = img.copyResize(
        image,
        height: maxSide,
        interpolation: img.Interpolation.linear,
      );
    }
  }

  if (image.hasAlpha) {
    final background = img.Image(width: image.width, height: image.height);
    img.fill(background, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(background, image);
    image = background;
  }

  return Uint8List.fromList(
    img.encodeJpg(image, quality: CropPreviewPrepare.previewJpegQuality),
  );
}
