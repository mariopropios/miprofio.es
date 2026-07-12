class AppConstants {
  AppConstants._();

  static const String appName = 'miProfio.es';
  static const String appTagline =
      'Encuentra y valora profesionales del hogar';

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;

  /// Shell escritorio web (NavigationRail). Por encima de iPad Pro (1024 px).
  static const double webDesktopMinWidth = 1280;

  static const int reviewsPerPage = 10;
  static const int companiesPerPage = 20;

  /// Máximo de fotos de trabajos en la galería del perfil profesional.
  static const int maxGalleryPhotos = 10;
}