import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/cookie_consent_banner.dart';
import 'shared/widgets/pwa_install_prompt.dart';

/// Scroll behavior sin scrollbar overlay, compatible con mouse y touch.
/// Evita que el scrollbar nativo de Flutter web se pinte encima del contenido.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

class ProfioApp extends ConsumerWidget {
  const ProfioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return PwaInstallOfferListener(
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        scrollBehavior: const _AppScrollBehavior(),
        routerConfig: router,
        builder: (context, child) {
          return CookieConsentHost(
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
