import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/legal_links_row.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../widgets/role_selection_card.dart';

// ── Banner "Solo buscas trabajadores" ─────────────────────────────────────────

class _BrowseBanner extends StatelessWidget {
  const _BrowseBanner({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primary,
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Solo buscas un trabajador?',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'No necesitas cuenta para explorar perfiles y comparar profesionales.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onBrowse,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Explorar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paso 1: selección de rol (cliente vs profesional).
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key, this.redirectTo});

  final String? redirectTo;

  String _withRedirect(String route) {
    if (redirectTo == null || redirectTo!.isEmpty) return route;
    return '$route?redirect=${Uri.encodeComponent(redirectTo!)}';
  }

  Widget _clientCard(BuildContext context) => RoleSelectionCard(
        icon: Icons.search_rounded,
        title: 'Busco Profesionales',
        subtitle:
            'Quiero dejar reseñas y guardar mis profesionales favoritos.',
        accentColor: const Color(0xFF4A9EFF),
        estimatedTime: 'menos de 1 min',
        highlights: const [
          'Escribe reseñas verificadas',
          'Chatea directamente con el profesional',
          'Guarda tus favoritos',
        ],
        onTap: () => context.push(_withRedirect(AppRoutes.clientRegister)),
      );

  Widget _professionalCard(BuildContext context) => RoleSelectionCard(
        icon: Icons.handyman_outlined,
        title: 'Ofrezco mis Servicios',
        subtitle:
            'Describe tu perfil profesional y empieza a recibir clientes.',
        estimatedTime: '~3 min',
        highlights: const [
          'Perfil con fotos y especialidades',
          'Aparece en búsquedas de tu zona',
          'Recibe mensajes de clientes',
        ],
        onTap: () =>
            context.push(_withRedirect(AppRoutes.professionalRegister)),
      );

  @override
  Widget build(BuildContext context) {
    final isWide = ResponsiveLayout.isDesktop(context);

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
                // ── Banner: "Solo buscas trabajadores" ────────────────────
                _BrowseBanner(onBrowse: () => context.go(AppRoutes.home)),
                const SizedBox(height: 28),

                Text(
                  '¿Quieres unirte a ${AppConstants.appName}?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                  textAlign: isWide ? TextAlign.center : TextAlign.start,
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige tu perfil y en menos de 3 minutos estarás dentro.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  textAlign: isWide ? TextAlign.center : TextAlign.start,
                ),
                const SizedBox(height: 28),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _clientCard(context)),
                      const SizedBox(width: 20),
                      Expanded(child: _professionalCard(context)),
                    ],
                  )
                else ...[
                  _clientCard(context),
                  const SizedBox(height: 16),
                  _professionalCard(context),
                ],
                const SizedBox(height: 28),
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
                const SizedBox(height: 20),
                const LegalLinksRow(dense: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
