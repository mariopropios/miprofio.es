import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/legal/legal_constants.dart';
import '../../../../core/theme/app_theme.dart';

/// Página del creador + feedback de producto (no es una ficha profesional).
class AboutFeedbackScreen extends StatelessWidget {
  const AboutFeedbackScreen({super.key});

  /// Destino del feedback (no se muestra en pantalla para limitar spam).
  static const _feedbackMailto = 'mariopropiosplaza@gmail.com';

  Future<void> _sendFeedback(
    BuildContext context, {
    required String subject,
    String? body,
  }) async {
    final query = StringBuffer(
      'subject=${Uri.encodeComponent(subject)}',
    );
    if (body != null && body.isNotEmpty) {
      query.write('&body=${Uri.encodeComponent(body)}');
    }
    final uri = Uri.parse('mailto:$_feedbackMailto?$query');
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo abrir el correo. Escribe a contacto@miprofio.es',
            ),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir el correo. Escribe a contacto@miprofio.es',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Acerca de'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              Text(
                LegalConstants.brandName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Directorio de profesionales del hogar con reseñas reales. '
                'Hecho en España, por una persona.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Creador',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      LegalConstants.controllerName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Diseño, desarrollo y producto de ${LegalConstants.brandName}. '
                      'Si algo falla o se puede mejorar, me ayuda mucho que me lo digas.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Feedback',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Elige qué quieres contar. Se abrirá tu app de correo '
                '(sin mostrar la dirección en esta página).',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 16),
              _FeedbackAction(
                icon: Icons.bug_report_outlined,
                label: 'Reportar un fallo',
                subtitle: 'Algo no funciona como debería',
                onTap: () => _sendFeedback(
                  context,
                  subject: 'Fallo en miProfio.es',
                  body:
                      'Qué pasó:\n\nEn qué pantalla / dispositivo:\n\n',
                ),
              ),
              const SizedBox(height: 10),
              _FeedbackAction(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Sugerir una mejora',
                subtitle: 'Ideas para que la web sea más útil',
                onTap: () => _sendFeedback(
                  context,
                  subject: 'Sugerencia para miProfio.es',
                  body: 'Mi idea:\n\n',
                ),
              ),
              const SizedBox(height: 10),
              _FeedbackAction(
                icon: Icons.mail_outline_rounded,
                label: 'Contactar al creador',
                subtitle: 'Dudas, prensa o lo que sea',
                onTap: () => _sendFeedback(
                  context,
                  subject: 'Contacto — miProfio.es',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'También puedes escribir a ${LegalConstants.contactEmail}.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackAction extends StatelessWidget {
  const _FeedbackAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_outward_rounded,
                color: AppTheme.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
