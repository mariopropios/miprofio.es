import 'package:flutter/material.dart';

import '../../core/utils/device_form_factor.dart';

enum ScreenSize { mobile, tablet, desktop }

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  static ScreenSize screenSizeOf(BuildContext context) {
    if (isDesktop(context)) return ScreenSize.desktop;
    if (isTablet(context)) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  /// Layout móvil (iPhone + iPad): bottom nav, deck de tarjetas, etc.
  static bool isMobile(BuildContext context) =>
      DeviceFormFactor.useMobileShell(context);

  static bool isTablet(BuildContext context) =>
      DeviceFormFactor.isTablet(context);

  /// Solo escritorio web (PC): NavigationRail lateral.
  static bool isDesktop(BuildContext context) =>
      DeviceFormFactor.isDesktopWeb(context);

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    }
    return mobile;
  }
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final adaptiveMax = DeviceFormFactor.contentMaxWidth(context);
    final effectiveMax = adaptiveMax.isFinite
        ? adaptiveMax.clamp(0, maxWidth).toDouble()
        : maxWidth;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMax),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
