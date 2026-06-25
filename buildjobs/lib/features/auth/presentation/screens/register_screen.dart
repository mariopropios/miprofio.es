import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../widgets/role_selection_card.dart';

/// Paso 1: selección de rol (cliente vs profesional).
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key, this.redirectTo});

  final String? redirectTo;

  String _withRedirect(String route) {
    if (redirectTo == null || redirectTo!.isEmpty) return route;
    return '$route?redirect=${Uri.encodeComponent(redirectTo!)}';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = !ResponsiveLayout.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.home);
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '¿Cómo quieres usar ${AppConstants.appName}?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                  textAlign: isWide ? TextAlign.center : TextAlign.start,
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige tu perfil para empezar con el flujo más adecuado.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: isWide ? TextAlign.center : TextAlign.start,
                ),
                const SizedBox(height: 36),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RoleSelectionCard(
                          icon: Icons.home_outlined,
                          title: 'Busco Profesionales',
                          subtitle:
                              'Encuentra albañiles, fontaneros y más cerca de ti. Deja reseñas y compara.',
                          accentColor: AppTheme.textPrimary,
                          onTap: () => context.push(_withRedirect(AppRoutes.clientRegister)),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: RoleSelectionCard(
                          icon: Icons.handyman_outlined,
                          title: 'Ofrezco mis Servicios',
                          subtitle:
                              'Publica tu perfil profesional, muestra tu trabajo y consigue nuevos clientes.',
                          onTap: () =>
                              context.push(_withRedirect(AppRoutes.professionalRegister)),
                        ),
                      ),
                    ],
                  )
                else ...[
                  RoleSelectionCard(
                    icon: Icons.home_outlined,
                    title: 'Busco Profesionales',
                    subtitle:
                        'Encuentra albañiles, fontaneros y más cerca de ti. Deja reseñas y compara.',
                    accentColor: AppTheme.textPrimary,
                    onTap: () => context.push(_withRedirect(AppRoutes.clientRegister)),
                  ),
                  const SizedBox(height: 16),
                  RoleSelectionCard(
                    icon: Icons.handyman_outlined,
                    title: 'Ofrezco mis Servicios',
                    subtitle:
                        'Publica tu perfil profesional, muestra tu trabajo y consigue nuevos clientes.',
                    onTap: () =>
                        context.push(_withRedirect(AppRoutes.professionalRegister)),
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿Ya tienes cuenta?',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
                        final redirect = redirectTo;
                        context.push(
                          redirect != null && redirect.isNotEmpty
                              ? AppRoutes.loginWithRedirect(redirect)
                              : AppRoutes.login,
                        );
                      },
                      child: const Text('Inicia sesión'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
