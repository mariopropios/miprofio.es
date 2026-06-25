import 'dart:typed_data';

import 'image_upload_optimizer_core.dart';

/// En web no se usa: la compresión nativa con canvas rompe CanvasKit al recargar.
Future<PreparedUpload> optimizeOnPlatform(
  Uint8List input, {
  String? originalName,
}) {
  throw StateError('optimizeOnPlatform no debe llamarse en web.');
}
