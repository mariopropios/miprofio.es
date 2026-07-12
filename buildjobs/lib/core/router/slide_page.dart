import 'package:flutter/material.dart';
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

/// Chat en el mismo navegador que la lista (transición nativa, sin flash).
Page<T> chatPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return MaterialPage<T>(
    key: key,
    fullscreenDialog: false,
    child: ColoredBox(
      color: AppTheme.scaffoldBackground,
      child: child,
    ),
  );
}
