import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/pwa_setup_helper.dart';

class _GuideStep {
  const _GuideStep(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

/// Panel visible debajo del AppBar de Mensajes (sin Overlay frágil).
class PwaHomeGuidePanel extends StatelessWidget {
  const PwaHomeGuidePanel({super.key, required this.onClose});

  final VoidCallback onClose;

  List<_GuideStep> _steps() {
    if (isIosWeb()) {
      return const [
        _GuideStep(
          'Pulsa Compartir',
          'Icono del cuadrado con flecha ↑, abajo en Safari.',
        ),
        _GuideStep(
          'Añadir a pantalla de inicio',
          'Desplázate en el menú y elige esa opción.',
        ),
        _GuideStep(
          'Pulsa Añadir',
          'Confirma y abre miProfio desde el icono nuevo.',
        ),
      ];
    }
    if (isAndroidWeb()) {
      if (canAutoInstallPwa()) {
        return const [
          _GuideStep(
            'Pulsa Instalar',
            'Usa el botón de abajo; el navegador pedirá confirmar.',
          ),
          _GuideStep(
            'Ábrela desde el inicio',
            'Usa el icono de miProfio, no la pestaña del navegador.',
          ),
        ];
      }
      return const [
        _GuideStep(
          'Abre el menú ⋮',
          'Arriba a la derecha en Chrome.',
        ),
        _GuideStep(
          'Instalar app',
          'Elige «Instalar app» o «Añadir a pantalla de inicio».',
        ),
        _GuideStep(
          'Ábrela desde el inicio',
          'Usa el icono de miProfio, no la pestaña del navegador.',
        ),
      ];
    }
    return const [
      _GuideStep(
        'Icono de instalar',
        'En la barra de direcciones (Chrome / Edge).',
      ),
      _GuideStep(
        'O desde el menú',
        'Menú → «Instalar miProfio.es».',
      ),
      _GuideStep(
        'Ábrela instalada',
        'Así los avisos funcionan mejor.',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    final inApp = isIosWeb() && isInAppBrowser();
    final canInstall = canAutoInstallPwa();

    return Material(
      color: AppTheme.surfaceElevated,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.add_to_home_screen_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Añade miProfio a tu inicio',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      height: 1.25,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Con el icono en el inicio, las notificaciones push funcionan '
              'mucho mejor (distinto de avisos por email).',
              style: TextStyle(
                color: Color(0xFFC8CDD2),
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (inApp) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0x33FF9800),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x99FF9800)),
                ),
                child: const Text(
                  'Si estás en Gmail o WhatsApp, abre este enlace en Safari '
                  'para poder añadir a inicio.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].subtitle,
                          style: const TextStyle(
                            color: Color(0xFFC8CDD2),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (canInstall) ...[
              FilledButton(
                onPressed: () async {
                  final ok = await triggerAutoInstallPwa();
                  if (ok) await dismissPwaInstallPrompt();
                  onClose();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Instalar / Añadir a inicio'),
              ),
              const SizedBox(height: 6),
            ],
            TextButton(
              onPressed: onClose,
              child: Text(
                canInstall ? 'Más tarde' : 'Entendido',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo simple (Perfil / CTA). Preferir panel in-page en Mensajes.
Future<void> showPwaHomeGuideDialog(BuildContext context) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        contentPadding: EdgeInsets.zero,
        content: SingleChildScrollView(
          child: PwaHomeGuidePanel(onClose: () => Navigator.pop(ctx)),
        ),
      );
    },
  );
}
