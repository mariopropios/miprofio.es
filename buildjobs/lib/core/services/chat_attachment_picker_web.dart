import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/chat/presentation/widgets/chat_attachment_menu.dart';

Future<XFile?> pickChatAttachment(ChatAttachmentSource source) =>
    pickChatAttachmentWeb(source);

Future<XFile?> pickChatAttachmentWeb(ChatAttachmentSource source) async {
  final picker = ImagePicker();
  switch (source) {
    case ChatAttachmentSource.gallery:
      return picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
    case ChatAttachmentSource.camera:
      return picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
      );
    case ChatAttachmentSource.file:
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;
      final picked = result.files.first;
      if (picked.bytes != null && picked.bytes!.isNotEmpty) {
        return XFile.fromData(
          picked.bytes!,
          name: picked.name,
          mimeType: picked.extension != null ? 'image/${picked.extension}' : null,
        );
      }
      if (picked.path != null) {
        return XFile(picked.path!, name: picked.name);
      }
      return null;
  }
}
