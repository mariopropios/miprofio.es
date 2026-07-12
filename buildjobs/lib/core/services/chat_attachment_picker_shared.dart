import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../../features/chat/presentation/widgets/chat_attachment_menu.dart';
import '../utils/x_file_bytes_reader.dart';

const _imageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif', 'bmp'];

/// Selector de adjuntos del chat (web, Android, iOS y escritorio).
Future<XFile?> pickChatAttachmentImpl(ChatAttachmentSource source) async {
  final picker = ImagePicker();
  switch (source) {
    case ChatAttachmentSource.gallery:
      return _normalizePicked(
        await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          requestFullMetadata: false,
        ),
      );
    case ChatAttachmentSource.camera:
      return _normalizePicked(
        await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          preferredCameraDevice: CameraDevice.rear,
          requestFullMetadata: false,
        ),
      );
    case ChatAttachmentSource.file:
      return _pickImageFile();
  }
}

/// Convierte blob URLs y rutas temporales a bytes en memoria (fiable en Android web).
Future<XFile?> _normalizePicked(XFile? file) async {
  if (file == null) return null;
  try {
    final bytes = await readXFileBytes(file);
    if (bytes.isEmpty) return file;
    return XFile.fromData(
      bytes,
      name: file.name.isNotEmpty ? file.name : 'photo.jpg',
      mimeType: file.mimeType ?? _mimeFromName(file.name),
    );
  } catch (_) {
    return file;
  }
}

Future<XFile?> _pickImageFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: _imageExtensions,
    allowMultiple: false,
    withData: kIsWeb,
  );
  if (result == null || result.files.isEmpty) return null;

  final picked = result.files.first;
  if (picked.bytes != null && picked.bytes!.isNotEmpty) {
    return XFile.fromData(
      picked.bytes!,
      name: picked.name,
      mimeType: _mimeFromName(picked.name),
    );
  }

  final path = picked.path;
  if (path != null && path.isNotEmpty) {
    return _normalizePicked(
      XFile(path, name: picked.name, mimeType: _mimeFromName(picked.name)),
    );
  }

  if (picked.readStream != null) {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in picked.readStream!) {
      builder.add(chunk);
    }
    final bytes = builder.takeBytes();
    if (bytes.isNotEmpty) {
      return XFile.fromData(
        bytes,
        name: picked.name,
        mimeType: _mimeFromName(picked.name),
      );
    }
  }

  return null;
}

String? _mimeFromName(String name) {
  final dot = name.lastIndexOf('.');
  if (dot == -1) return 'image/jpeg';
  switch (name.substring(dot + 1).toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'gif':
      return 'image/gif';
    case 'heic':
      return 'image/heic';
    case 'heif':
      return 'image/heif';
    case 'bmp':
      return 'image/bmp';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}
