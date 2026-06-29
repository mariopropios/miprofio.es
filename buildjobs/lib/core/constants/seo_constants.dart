/// URLs y textos base para SEO web (Fase 0+).
abstract final class SeoConstants {
  SeoConstants._();

  /// Dominio canónico público. Actualizar si el despliegue usa otro host.
  static const siteUrl = 'https://profio.app';

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

  static String get ogImageUrl => '$siteUrl$ogImagePath';
}
