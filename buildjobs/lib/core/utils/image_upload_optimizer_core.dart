import 'dart:typed_data';

import 'package:image/image.dart' as img;

class PreparedUpload {
  const PreparedUpload({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
}

/// Lógica de compresión (sin dependencias web nativas).
class ImageUploadOptimizerCore {
  ImageUploadOptimizerCore._();

  static const targetMaxBytes = 4 * 1024 * 1024;
  static const bucketMaxBytes = 20 * 1024 * 1024;
  static const maxDimension = 1920;
  static const fallbackMaxDimension = 1280;
  static const optimizeTimeout = Duration(seconds: 45);

  static PreparedUpload prepareSmall(
    Uint8List input, {
    String? originalName,
  }) {
    final ext = _extensionFromName(originalName) ?? 'jpg';
    return PreparedUpload(
      bytes: input,
      extension: ext,
      contentType: _contentTypeForExtension(ext),
    );
  }

  static PreparedUpload prepareSync(
    Uint8List input, {
    String? originalName,
  }) {
    final decoded = img.decodeImage(input);
    if (decoded == null) {
      if (input.length <= bucketMaxBytes) {
        return prepareSmall(input, originalName: originalName);
      }
      throw const FormatException(
        'No se pudo procesar la imagen. Prueba con JPG, PNG o WebP.',
      );
    }

    var image = _resizeIfNeeded(decoded, maxDimension);

    final pngCandidate = _tryEncodePng(image);
    if (pngCandidate != null) {
      return pngCandidate;
    }

    final jpeg = _encodeJpegUnderLimit(image);
    if (jpeg != null) {
      return jpeg;
    }

    image = _resizeIfNeeded(decoded, fallbackMaxDimension);
    final fallback = _encodeJpegUnderLimit(image);
    if (fallback != null) {
      return fallback;
    }

    throw StateError(
      'La imagen es demasiado grande. Prueba con otra foto más pequeña.',
    );
  }

  static img.Image _resizeIfNeeded(img.Image image, int maxSide) {
    if (image.width <= maxSide && image.height <= maxSide) {
      return image;
    }

    if (image.width >= image.height) {
      return img.copyResize(image, width: maxSide);
    }
    return img.copyResize(image, height: maxSide);
  }

  static PreparedUpload? _tryEncodePng(img.Image image) {
    if (!image.hasAlpha) return null;

    for (final level in [6, 8, 9]) {
      final bytes = Uint8List.fromList(img.encodePng(image, level: level));
      if (bytes.length <= targetMaxBytes) {
        return PreparedUpload(
          bytes: bytes,
          extension: 'png',
          contentType: 'image/png',
        );
      }
    }
    return null;
  }

  static PreparedUpload? _encodeJpegUnderLimit(img.Image image) {
    final working = _flattenAlpha(image);

    for (var quality = 88; quality >= 45; quality -= 7) {
      final bytes =
          Uint8List.fromList(img.encodeJpg(working, quality: quality));
      if (bytes.length <= targetMaxBytes) {
        return PreparedUpload(
          bytes: bytes,
          extension: 'jpg',
          contentType: 'image/jpeg',
        );
      }
    }
    return null;
  }

  static img.Image _flattenAlpha(img.Image image) {
    if (!image.hasAlpha) return image;

    final background = img.Image(width: image.width, height: image.height);
    img.fill(background, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(background, image);
    return background;
  }

  static String? _extensionFromName(String? name) {
    if (name == null || !name.contains('.')) return null;
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpeg' => 'jpg',
      'tif' => 'tiff',
      _ => ext,
    };
  }

  static String _contentTypeForExtension(String ext) {
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'bmp' => 'image/bmp',
      'tiff' => 'image/tiff',
      'heic' || 'heif' => 'image/heic',
      'avif' => 'image/avif',
      _ => 'image/jpeg',
    };
  }
}
