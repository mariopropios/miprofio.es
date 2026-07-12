import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Página con slide lateral sin parallax (evita flash al volver atrás).
Page<T> slidePage<T>({
  required LocalKey key,
  required Widget child,
  bool maintainState = true,
}) {
  return CustomTransitionPage<T>(
    key: key,
    opaque: true,
    maintainState: maintainState,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    child: ColoredBox(
      color: AppTheme.scaffoldBackground,
      child: child,
    ),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      // Solo desliza la pantalla actual; la de debajo queda quieta (sin flash).
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: ColoredBox(
          color: AppTheme.scaffoldBackground,
          child: child,
        ),
      );
    },
  );
}
