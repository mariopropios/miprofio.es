import 'ios_pwa_helper_stub.dart'
    if (dart.library.html) 'ios_pwa_helper_web.dart' as impl;

/// iPhone/iPad en Safari sin instalar la PWA en pantalla de inicio.
bool shouldShowIosPwaInstallBanner() => impl.shouldShowIosPwaInstallBanner();

Future<bool> isIosPwaBannerDismissed() => impl.isIosPwaBannerDismissed();

Future<void> dismissIosPwaBanner() => impl.dismissIosPwaBanner();
