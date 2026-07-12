// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

import '../../features/chat/presentation/widgets/chat_attachment_menu.dart';

Future<XFile?> pickChatAttachment(ChatAttachmentSource source) =>
    pickChatAttachmentWeb(source);

Future<XFile?> pickChatAttachmentWeb(ChatAttachmentSource source) async {
  final input = html.FileUploadInputElement()
    ..style.display = 'none'
    ..multiple = false;

  switch (source) {
    case ChatAttachmentSource.gallery:
      input.accept = 'image/png,image/jpeg,image/jpg,image/webp,image/gif,image/heic,image/heif';
      break;
    case ChatAttachmentSource.camera:
      input.accept = 'image/*';
      input.setAttribute('capture', 'environment');
      break;
    case ChatAttachmentSource.file:
      input.accept =
          'image/png,image/jpeg,image/jpg,image/webp,image/gif,image/heic,image/heif,image/bmp,.png,.jpg,.jpeg,.webp,.gif,.heic,.heif';
      break;
  }

  html.document.body?.append(input);

  final completer = Completer<XFile?>();

  void cleanup() => input.remove();

  input.onChange.first.then((_) async {
    try {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        return;
      }

      final file = files.first;
      final reader = html.FileReader();
      final loadDone = reader.onLoadEnd.first;
      reader.readAsArrayBuffer(file);
      await loadDone;

      final result = reader.result;
      if (result is! ByteBuffer || result.lengthInBytes == 0) {
        completer.complete(null);
        return;
      }

      completer.complete(
        XFile.fromData(
          Uint8List.view(result),
          name: file.name,
          mimeType: file.type.isNotEmpty ? file.type : 'image/jpeg',
        ),
      );
    } catch (_) {
      completer.complete(null);
    } finally {
      cleanup();
    }
  });

  // Debe ejecutarse en el mismo gesto del usuario (tap en el menú).
  input.click();

  return completer.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      cleanup();
      return null;
    },
  );
}
