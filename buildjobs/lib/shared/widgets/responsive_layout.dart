import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

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
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppConstants.desktopBreakpoint) return ScreenSize.desktop;
    if (width >= AppConstants.tabletBreakpoint) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  /// Devuelve true para teléfonos Y tablets pequeñas (< 1024 px).
  /// Garantiza que iPads de menos de 1024 px usen el layout de móvil.
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppConstants.tabletBreakpoint;

  /// Devuelve true para tablets en la franja 600–1023 px.
  static bool isTablet(BuildContext context) =>
      screenSizeOf(context) == ScreenSize.tablet;

  /// Devuelve true sólo para pantallas de escritorio (>= 1024 px).
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= AppConstants.tabletBreakpoint) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
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
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
