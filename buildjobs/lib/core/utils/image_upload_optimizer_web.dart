import 'package:flutter/foundation.dart';

import 'image_upload_optimizer_core.dart';

class _OptimizeRequest {
  const _OptimizeRequest(this.bytes, this.originalName);

  final Uint8List bytes;
  final String? originalName;
}

/// Top-level para [compute] / web worker (sin canvas HTML).
PreparedUpload _optimizeInWorker(_OptimizeRequest request) {
  return ImageUploadOptimizerCore.prepareSync(
    request.bytes,
    originalName: request.originalName,
  );
}

/// Compresión en web con `package:image`.
/// Intenta [compute]; si falla, comprime en el mismo isolate (sin canvas DOM).
Future<PreparedUpload> optimizeOnPlatform(
  Uint8List input, {
  String? originalName,
}) async {
  try {
    return await compute(
      _optimizeInWorker,
      _OptimizeRequest(input, originalName),
    ).timeout(const Duration(seconds: 35));
  } catch (e) {
    debugPrint('[ImageOptimize] compute web falló, fallback sync: $e');
    return ImageUploadOptimizerCore.prepareSync(
      input,
      originalName: originalName,
    );
  }
}
