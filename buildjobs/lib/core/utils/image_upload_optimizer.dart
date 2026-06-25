import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'image_upload_optimizer_core.dart';
import 'image_upload_optimizer_io.dart'
    if (dart.library.html) 'image_upload_optimizer_stub.dart'
    as optimizer_impl;

export 'image_upload_optimizer_core.dart' show PreparedUpload;

/// Comprime y redimensiona imágenes antes de subirlas a Storage.
class ImageUploadOptimizer {
  ImageUploadOptimizer._();

  static const targetMaxBytes = ImageUploadOptimizerCore.targetMaxBytes;
  static const bucketMaxBytes = ImageUploadOptimizerCore.bucketMaxBytes;
  static const optimizeTimeout = ImageUploadOptimizerCore.optimizeTimeout;

  static Future<PreparedUpload> prepareUpload(
    Uint8List input, {
    String? originalName,
  }) {
    if (input.isEmpty) {
      return Future.error(StateError('La imagen seleccionada está vacía.'));
    }

    if (input.length <= targetMaxBytes) {
      return Future.value(
        ImageUploadOptimizerCore.prepareSmall(
          input,
          originalName: originalName,
        ),
      );
    }

    // Web: subir tal cual hasta 20 MB (sin canvas nativo → no rompe la recarga).
    if (kIsWeb) {
      if (input.length <= bucketMaxBytes) {
        return Future.value(
          ImageUploadOptimizerCore.prepareSmall(
            input,
            originalName: originalName,
          ),
        );
      }
      return Future.error(
        StateError(
          'La imagen pesa demasiado (máx. 20 MB). '
          'Prueba con otra más pequeña o comprímela antes.',
        ),
      );
    }

    return optimizer_impl.optimizeOnPlatform(
      input,
      originalName: originalName,
    );
  }
}
