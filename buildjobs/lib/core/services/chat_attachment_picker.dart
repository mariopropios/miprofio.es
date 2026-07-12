import 'package:cross_file/cross_file.dart';

import '../../features/chat/presentation/widgets/chat_attachment_menu.dart';
import 'chat_attachment_picker_stub.dart'
    if (dart.library.html) 'chat_attachment_picker_web.dart' as impl;

/// Abre el selector nativo acorde a la opción elegida en el menú del chat.
abstract final class ChatAttachmentPicker {
  static Future<XFile?> pick(ChatAttachmentSource source) =>
      impl.pickChatAttachment(source);
}
