import 'dart:async';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/image_upload_optimizer.dart';
import '../utils/x_file_bytes_reader.dart';

class ProfilePhotoStorage {
  ProfilePhotoStorage(this._client);

  final SupabaseClient _client;

  static const uploadTimeout = Duration(seconds: 60);

  Future<String> uploadImage(XFile file, String userId) async {
    if (_client.auth.currentSession == null) {
      throw StateError(
        'Debes tener sesión activa para subir fotos.',
      );
    }

    final rawBytes = await readXFileBytes(file).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException('Lectura de la imagen'),
    );

    final prepared = await ImageUploadOptimizer.prepareUpload(
      rawBytes,
      originalName: file.name,
    ).timeout(ImageUploadOptimizer.optimizeTimeout);

    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.${prepared.extension}';

    await _client.storage
        .from('profile-photos')
        .uploadBinary(
          path,
          prepared.bytes,
          fileOptions: FileOptions(
            contentType: prepared.contentType,
            upsert: true,
          ),
        )
        .timeout(uploadTimeout);

    return _client.storage.from('profile-photos').getPublicUrl(path);
  }

  Future<List<String>> uploadGalleryImages(
    List<XFile> files,
    String userId,
  ) async {
    final urls = <String>[];
    for (final file in files) {
      urls.add(await uploadImage(file, userId));
    }
    return urls;
  }

  static String friendlyErrorMessage(StorageException error) {
    final message = error.message.toLowerCase();
    if (message.contains('maximum allowed size') ||
        message.contains('payload too large')) {
      return 'La imagen es demasiado pesada. Se comprimirá automáticamente; '
          'si el error continúa, prueba con otra foto.';
    }
    if (message.contains('mime') || message.contains('content type')) {
      return 'Formato no admitido. Usa JPG, PNG, WebP, GIF, BMP o TIFF.';
    }
    return 'No se pudieron guardar las fotos: ${error.message}';
  }
}
