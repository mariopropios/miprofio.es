import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'device_form_factor_stub.dart'
    if (dart.library.html) 'device_form_factor_web.dart' as platform;

/// Clasifica el dispositivo para elegir shell móvil vs escritorio web.
abstract final class DeviceFormFactor {
  DeviceFormFactor._();

  /// Ancho máximo del “marco iPhone ampliado” en tablet.
  static const tabletContentMaxWidth = 680.0;

  /// iPad (nativo o web) y tablets Android.
  static bool isTablet(BuildContext context) {
    if (platform.isIpadLikeUserAgent()) return true;

    final size = MediaQuery.sizeOf(context);
    final shortestSide = size.shortestSide;

    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.iOS && shortestSide >= 744) {
        return true;
      }
      if (defaultTargetPlatform == TargetPlatform.android &&
          shortestSide >= 600 &&
          size.longestSide < 1280) {
        return true;
      }
    }

    // En web confiamos en el user-agent (iPad real o emulación DevTools).
    return false;
  }

  /// Escritorio web con barra lateral (PC, ventana ancha sin ser tablet).
  static bool isDesktopWeb(BuildContext context) {
    if (!kIsWeb) return false;
    if (isTablet(context)) return false;
    return MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;
  }

  /// iPhone y iPad usan shell móvil (NavigationBar inferior).
  static bool useMobileShell(BuildContext context) =>
      !isDesktopWeb(context);

  /// Teléfono (no tablet ni escritorio web).
  static bool isPhone(BuildContext context) =>
      !isTablet(context) && !isDesktopWeb(context);

  static double contentMaxWidth(BuildContext context) {
    if (isDesktopWeb(context)) return 1200;
    if (isTablet(context)) return tabletContentMaxWidth;
    return double.infinity;
  }

  /// Centra la app en tablet con márgenes laterales (estilo iPhone ampliado).
  static bool shouldFrameTabletContent(BuildContext context) =>
      isTablet(context);
}

/// Envuelve [child] en un marco centrado en iPad/tablet.
class TabletAdaptiveFrame extends StatelessWidget {
  const TabletAdaptiveFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!DeviceFormFactor.shouldFrameTabletContent(context)) {
      return child;
    }

    return ColoredBox(
      color: const Color(0xFF080C10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: DeviceFormFactor.tabletContentMaxWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}
