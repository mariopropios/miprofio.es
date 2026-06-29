import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';

/// Muestra un aviso al llegar al perfil tras verificar el email.
class EmailVerifiedWelcomeListener extends StatefulWidget {
  const EmailVerifiedWelcomeListener({super.key, required this.child});

  final Widget child;

  @override
  State<EmailVerifiedWelcomeListener> createState() =>
      _EmailVerifiedWelcomeListenerState();
}

class _EmailVerifiedWelcomeListenerState
    extends State<EmailVerifiedWelcomeListener> {
  bool _shown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeShowWelcome();
  }

  void _maybeShowWelcome() {
    if (_shown || !mounted) return;

    final uri = GoRouterState.of(context).uri;
    if (!AppRoutes.isProfileEmailVerified(uri)) return;

    _shown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);

      messenger.showMaterialBanner(
        MaterialBanner(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
          surfaceTintColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¡Email verificado!',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Hemos guardado tu sesión en este dispositivo. '
                'No necesitarás iniciar sesión de nuevo.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: Text(
                'Entendido',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      context.replace(AppRoutes.profile);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
