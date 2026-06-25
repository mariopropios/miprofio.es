import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

Future<Uint8List> readXFileBytesImpl(XFile file) async {
  return file.readAsBytes().timeout(const Duration(seconds: 15));
}
