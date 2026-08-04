import 'web_seo_meta_stub.dart'
    if (dart.library.html) 'web_seo_meta_web.dart' as impl;

/// Actualiza title/description/canonical en el documento web (no-op en otras plataformas).
void applyWebSeoMeta({
  required String title,
  required String description,
  String? canonicalPath,
}) {
  impl.applyWebSeoMeta(
    title: title,
    description: description,
    canonicalPath: canonicalPath,
  );
}
