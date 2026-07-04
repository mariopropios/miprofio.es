import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Cabecera fija para [CustomScrollView] (título Inicio, filtros Buscar).
class PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const PinnedHeaderDelegate({
    required this.extent,
    required this.child,
  });

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: AppTheme.scaffoldBackground,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant PinnedHeaderDelegate oldDelegate) =>
      extent != oldDelegate.extent || child != oldDelegate.child;
}
