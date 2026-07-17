import 'package:flutter/foundation.dart';

import 'image_upload_optimizer_core.dart';
import 'image_upload_optimizer_io.dart'
    if (dart.library.html) 'image_upload_optimizer_web.dart'
    as optimizer_impl;

export 'image_upload_optimizer_core.dart' show PreparedUpload;

/// Comprime y redimensiona imágenes antes de subirlas a Storage.
///
/// Web y móvil usan `package:image` (Dart puro) vía [compute].
/// No usa canvas HTML → no rompe CanvasKit / PWA iOS.
class ImageUploadOptimizer {
  ImageUploadOptimizer._();

  static const targetMaxBytes = ImageUploadOptimizerCore.targetMaxBytes;
  static const bucketMaxBytes = ImageUploadOptimizerCore.bucketMaxBytes;
  static const optimizeTimeout = ImageUploadOptimizerCore.optimizeTimeout;

  static Future<PreparedUpload> prepareUpload(
    Uint8List input, {
    String? originalName,
  }) async {
    if (input.isEmpty) {
      throw StateError('La imagen seleccionada está vacía.');
    }

    if (input.length > bucketMaxBytes) {
      throw StateError(
        'La imagen pesa demasiado (máx. 20 MB). '
        'Prueba con otra más pequeña.',
      );
    }

    // Ya es ligera: no gastar CPU re-encodeando.
    if (input.length <= ImageUploadOptimizerCore.skipIfUnderBytes) {
      return ImageUploadOptimizerCore.prepareSmall(
        input,
        originalName: originalName,
      );
    }

    return optimizer_impl.optimizeOnPlatform(
      input,
      originalName: originalName,
    );
  }
}
