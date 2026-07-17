import 'dart:typed_data';

/// Lee ancho/alto desde cabeceras JPEG/PNG sin decodificar toda la imagen.
/// Devuelve null si el formato no es reconocible (HEIC, etc.).
({int width, int height})? readImageBounds(Uint8List bytes) {
  if (bytes.length < 24) return null;

  // PNG: 8-byte signature + IHDR
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    if (bytes.length < 24) return null;
    final width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final height =
        (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    if (width > 0 && height > 0) return (width: width, height: height);
    return null;
  }

  // JPEG: buscar SOF0 / SOF2
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
    var i = 2;
    while (i + 9 < bytes.length) {
      if (bytes[i] != 0xFF) {
        i++;
        continue;
      }
      final marker = bytes[i + 1];
      if (marker == 0xD9 || marker == 0xDA) break;
      if (i + 4 >= bytes.length) break;
      final len = (bytes[i + 2] << 8) | bytes[i + 3];
      if (len < 2) break;

      // Baseline / progressive DCT
      if (marker == 0xC0 ||
          marker == 0xC1 ||
          marker == 0xC2 ||
          marker == 0xC3) {
        if (i + 8 >= bytes.length) break;
        final height = (bytes[i + 5] << 8) | bytes[i + 6];
        final width = (bytes[i + 7] << 8) | bytes[i + 8];
        if (width > 0 && height > 0) return (width: width, height: height);
        return null;
      }
      i += 2 + len;
    }
  }

  // WebP (VP8X / VP8)
  if (bytes.length > 30 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    final chunk = String.fromCharCodes(bytes.sublist(12, 16));
    if (chunk == 'VP8X' && bytes.length >= 30) {
      final width =
          1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16));
      final height =
          1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16));
      if (width > 0 && height > 0) return (width: width, height: height);
    }
  }

  return null;
}
