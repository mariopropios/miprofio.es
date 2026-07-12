import 'package:cross_file/cross_file.dart';

import '../../features/chat/presentation/widgets/chat_attachment_menu.dart';
import 'chat_attachment_picker_shared.dart';

Future<XFile?> pickChatAttachment(ChatAttachmentSource source) =>
    pickChatAttachmentImpl(source);

Future<XFile?> pickChatAttachmentNative(ChatAttachmentSource source) =>
    pickChatAttachmentImpl(source);
