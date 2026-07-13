import 'dart:typed_data';

import 'web_blob_bytes_reader_stub.dart'
    if (dart.library.html) 'web_blob_bytes_reader_web.dart';

/// Lee bytes desde una URL tipo `blob:` (solo web).
Future<Uint8List> readWebBlobBytes(String url) => readWebBlobBytesImpl(url);

