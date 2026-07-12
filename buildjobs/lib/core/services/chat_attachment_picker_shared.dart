import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../../features/chat/presentation/widgets/chat_attachment_menu.dart';

const _imageExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif', 'bmp'];

/// Selector de adjuntos del chat (web, Android, iOS y escritorio).
Future<XFile?> pickChatAttachmentImpl(ChatAttachmentSource source) async {
  final picker = ImagePicker();
  switch (source) {
    case ChatAttachmentSource.gallery:
      return picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        requestFullMetadata: false,
      );
    case ChatAttachmentSource.camera:
      return picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: false,
      );
    case ChatAttachmentSource.file:
      return _pickImageFile();
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
    return XFile(path, name: picked.name, mimeType: _mimeFromName(picked.name));
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
