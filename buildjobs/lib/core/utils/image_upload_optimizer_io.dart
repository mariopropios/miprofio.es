import 'package:flutter/foundation.dart';

import 'image_upload_optimizer_core.dart';

class _OptimizeRequest {
  const _OptimizeRequest(this.bytes, this.originalName);

  final Uint8List bytes;
  final String? originalName;
}

PreparedUpload _optimizeInIsolate(_OptimizeRequest request) {
  return ImageUploadOptimizerCore.prepareSync(
    request.bytes,
    originalName: request.originalName,
  );
}

/// Compresión en isolate (móvil / desktop).
Future<PreparedUpload> optimizeOnPlatform(
  Uint8List input, {
  String? originalName,
}) {
  return compute(
    _optimizeInIsolate,
    _OptimizeRequest(input, originalName),
  );
}
