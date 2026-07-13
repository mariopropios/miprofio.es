import 'dart:typed_data';
import 'dart:html' as html;

Future<Uint8List> readWebBlobBytesImpl(String url) async {
  final req = await html.HttpRequest.request(
    url,
    method: 'GET',
    responseType: 'arraybuffer',
  );
  final buffer = req.response as ByteBuffer?;
  if (buffer == null) return Uint8List(0);
  return Uint8List.view(buffer);
}

