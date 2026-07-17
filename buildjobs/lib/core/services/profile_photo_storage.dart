import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/image_upload_optimizer.dart';
import '../utils/x_file_bytes_reader.dart';

class ProfilePhotoStorage {
  ProfilePhotoStorage(this._client);

  final SupabaseClient _client;

  static const uploadTimeout = Duration(seconds: 60);

  /// Paralelismo de comprimir+subir (evita saturar CPU/red con 10 fotos).
  static const galleryUploadConcurrency = 3;

  Future<String> uploadImage(XFile file, String userId) async {
    final rawBytes = await readXFileBytes(file).timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw TimeoutException('Lectura de la imagen'),
    );
    return uploadBytes(
      rawBytes: rawBytes,
      userId: userId,
      originalName: file.name,
    );
  }

  /// Subida desde bytes ya leídos (válido tras cerrar el picker / cambiar de pantalla).
  Future<String> uploadBytes({
    required Uint8List rawBytes,
    required String userId,
    String? originalName,
  }) async {
    if (_client.auth.currentSession == null) {
      throw StateError(
        'Debes tener sesión activa para subir fotos.',
      );
    }

    late final PreparedUpload prepared;
    try {
      prepared = await ImageUploadOptimizer.prepareUpload(
        rawBytes,
        originalName: originalName,
      ).timeout(ImageUploadOptimizer.optimizeTimeout);
    } on FormatException catch (e) {
      throw StateError(e.message);
    }

    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.${prepared.extension}';

    try {
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
    } on StorageException catch (e) {
      throw StateError(friendlyErrorMessage(e));
    }

    final url = _client.storage.from('profile-photos').getPublicUrl(path);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<List<String>> uploadGalleryImages(
    List<XFile> files,
    String userId,
  ) async {
    if (files.isEmpty) return [];
    final items = <({Uint8List bytes, String name})>[];
    for (final file in files) {
      final bytes = await readXFileBytes(file).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('Lectura de la imagen'),
      );
      items.add((bytes: bytes, name: file.name));
    }
    return uploadGalleryBytes(items: items, userId: userId);
  }

  Future<List<String>> uploadGalleryBytes({
    required List<({Uint8List bytes, String name})> items,
    required String userId,
  }) async {
    if (items.isEmpty) return [];

    final results = List<String?>.filled(items.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final i = nextIndex;
        if (i >= items.length) return;
        nextIndex++;
        final item = items[i];
        results[i] = await uploadBytes(
          rawBytes: item.bytes,
          userId: userId,
          originalName: item.name,
        );
      }
    }

    final workers = galleryUploadConcurrency.clamp(1, items.length);
    await Future.wait(List.generate(workers, (_) => worker()));
    return results.cast<String>();
  }

  static String friendlyErrorMessage(Object error) {
    if (error is StorageException) {
      final message = error.message.toLowerCase();
      if (message.contains('maximum allowed size') ||
          message.contains('payload too large')) {
        return 'La imagen es demasiado pesada. '
            'Prueba con otra foto más pequeña.';
      }
      if (message.contains('mime') || message.contains('content type')) {
        return 'Formato no admitido. Usa JPG, PNG o WebP.';
      }
      if (message.contains('row-level security') ||
          message.contains('unauthorized') ||
          message.contains('jwt')) {
        return 'Sesión caducada o sin permiso para subir fotos. '
            'Vuelve a iniciar sesión.';
      }
      return 'No se pudieron guardar las fotos: ${error.message}';
    }
    if (error is TimeoutException) {
      return 'La subida de fotos ha tardado demasiado. Inténtalo de nuevo.';
    }
    if (error is StateError) return error.message;
    if (error is FormatException) {
      return error.message.isNotEmpty
          ? error.message
          : 'No se pudo procesar la imagen. Prueba con JPG o PNG.';
    }
    final text = error.toString();
    if (text.contains('ref') && text.contains('disposed')) {
      return 'No se pudieron subir las fotos. Inténtalo de nuevo.';
    }
    return 'No se pudieron guardar las fotos.';
  }
}
