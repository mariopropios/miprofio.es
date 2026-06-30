/// URLs y textos base para SEO web (Fase 0+).
abstract final class SeoConstants {
  SeoConstants._();

  /// Dominio canónico público. Actualizar si el despliegue usa otro host.
  static const siteUrl = 'https://miprofio.es';

  /// Email de contacto público (User-Agent APIs, pie de página, etc.).
  static const contactEmail = 'contacto@miprofio.es';

  static const siteName = 'Profio';
  static const defaultTitle =
      'Profio · Profesionales del hogar con reseñas en España';
  static const defaultDescription =
      'Encuentra fontaneros, electricistas, albañiles y más profesionales '
      'del hogar cerca de ti. Compara reseñas, distancia y contacta gratis.';
  static const locale = 'es_ES';
  static const languageCode = 'es-ES';
  static const ogImagePath = '/favicon.png';
  static const twitterHandle = '@profioapp';

  static const publicUserAgent =
      'ProfioApp/1.0 (profio; contacto@miprofio.es)';

  static String get ogImageUrl => '$siteUrl$ogImagePath';
}
