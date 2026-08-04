import '../constants/seo_constants.dart';

/// Datos del responsable del tratamiento / titular del sitio.
/// Completa los campos marcados antes de producción legal definitiva.
abstract final class LegalConstants {
  LegalConstants._();

  static const siteName = SeoConstants.siteName;
  static const siteUrl = SeoConstants.siteUrl;
  static const contactEmail = SeoConstants.contactEmail;

  /// Nombre comercial / marca.
  static const brandName = 'miProfio.es';

  /// Titular del sitio / responsable del tratamiento.
  static const controllerName = 'Mario Propios Plaza';

  /// NIF del titular.
  static const taxId = '77025168P';

  /// Localidad del titular (sin calle, por privacidad en web pública).
  static const address = 'Madrigal de la Vera (Cáceres), España';

  static const lastUpdated = '5 de agosto de 2026';

  static const disclaimer =
      'Textos orientativos para cumplimiento básico. '
      'No sustituyen el asesoramiento de un abogado.';
}
