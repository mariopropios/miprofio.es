import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'x_file_bytes_reader_stub.dart'
    if (dart.library.html) 'x_file_bytes_reader_web.dart';

Future<Uint8List> readXFileBytes(XFile file) async {
  return readXFileBytesImpl(file);
}
