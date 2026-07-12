// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

Future<Uint8List> readXFileBytesImpl(XFile file) async {
  try {
    final bytes = await file.readAsBytes().timeout(const Duration(seconds: 15));
    if (bytes.isNotEmpty) return bytes;
  } catch (_) {
    // Fallback para blob URLs en web móvil.
  }

  final path = file.path;
  if (path.startsWith('blob:') || path.startsWith('data:')) {
    return _uriToBytes(path);
  }

  throw StateError('No se pudieron leer los bytes de ${file.name}');
}

Future<Uint8List> _uriToBytes(String url) async {
  final request = await html.HttpRequest.request(
    url,
    responseType: 'arraybuffer',
  ).timeout(const Duration(seconds: 15));

  final buffer = request.response;
  if (buffer is ByteBuffer) {
    return Uint8List.view(buffer);
  }
  throw StateError('Respuesta de imagen no válida');
}
