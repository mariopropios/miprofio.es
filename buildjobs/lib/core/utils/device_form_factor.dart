import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'device_form_factor_stub.dart'
    if (dart.library.html) 'device_form_factor_web.dart' as platform;

/// Clasifica el dispositivo para elegir shell móvil vs escritorio web.
abstract final class DeviceFormFactor {
  DeviceFormFactor._();

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
      return false;
    }

    // Web: iPad Air/Pro/Mini aunque DevTools no envíe user-agent iPad (común en Pro 1024).
    if (shortestSide >= 744 && size.width < AppConstants.webDesktopMinWidth) {
      return true;
    }

    return false;
  }

  /// Escritorio web con barra lateral (PC, ventana ancha sin ser tablet).
  static bool isDesktopWeb(BuildContext context) {
    if (!kIsWeb) return false;
    if (isTablet(context)) return false;
    return MediaQuery.sizeOf(context).width >= AppConstants.webDesktopMinWidth;
  }

  /// iPhone y iPad usan shell móvil (NavigationBar inferior).
  static bool useMobileShell(BuildContext context) =>
      !isDesktopWeb(context);

  /// Teléfono (no tablet ni escritorio web).
  static bool isPhone(BuildContext context) =>
      !isTablet(context) && !isDesktopWeb(context);

  static double contentMaxWidth(BuildContext context) {
    if (isDesktopWeb(context)) return 1200;
    return double.infinity;
  }
}
