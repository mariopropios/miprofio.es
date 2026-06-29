/// URLs optimizadas para imágenes en Supabase Storage.
abstract final class StorageImageUrl {
  StorageImageUrl._();

  static bool isSupabasePublicStorage(String url) {
    return url.contains('/storage/v1/object/public/');
  }

  /// Miniatura servida por Supabase (mucho menos peso que el original).
  /// Si la URL no es de Supabase, devuelve la original.
  static String thumbnail(
    String publicUrl, {
    required int width,
    required int height,
    int quality = 78,
  }) {
    if (!isSupabasePublicStorage(publicUrl)) return publicUrl;

    final uri = Uri.parse(publicUrl);
    final renderPath = uri.path.replaceFirst(
      '/storage/v1/object/public/',
      '/storage/v1/render/image/public/',
    );

    return uri.replace(
      path: renderPath,
      queryParameters: {
        'width': '$width',
        'height': '$height',
        'resize': 'cover',
        'quality': '$quality',
      },
    ).toString();
  }

  /// Imagen intermedia para cabeceras / visor (no el archivo completo).
  static String display(
    String publicUrl, {
    required int maxWidth,
    int quality = 82,
  }) {
    if (!isSupabasePublicStorage(publicUrl)) return publicUrl;

    final uri = Uri.parse(publicUrl);
    final renderPath = uri.path.replaceFirst(
      '/storage/v1/object/public/',
      '/storage/v1/render/image/public/',
    );

    return uri.replace(
      path: renderPath,
      queryParameters: {
        'width': '$maxWidth',
        'resize': 'contain',
        'quality': '$quality',
      },
    ).toString();
  }
}
