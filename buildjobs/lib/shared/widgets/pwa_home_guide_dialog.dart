import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/pwa_setup_helper.dart';

/// Panel in-page (sin Navigator/showDialog) — fiable en iOS Safari / ShellRoute.
class PwaHomeGuideOverlay extends StatelessWidget {
  const PwaHomeGuideOverlay({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isIos = isIosWeb();
    final isAndroid = isAndroidWeb();
    final inApp = isInAppBrowser();
    final alreadyIn = !lacksPwaDirectAccess();
    final canInstall = canAutoInstallPwa();

    final steps = <(String, String)>[
      if (isIos) ...[
        (
          '1. Pulsa Compartir',
          'El icono del cuadrado con flecha ↑, abajo en Safari.',
        ),
        (
          '2. Añadir a pantalla de inicio',
          'Desplázate en el menú y elige esa opción.',
        ),
        (
          '3. Pulsa Añadir',
          'Confirma. Luego abre miProfio desde el icono nuevo.',
        ),
      ] else if (isAndroid) ...[
        if (canInstall)
          (
            '1. Pulsa Instalar abajo',
            'El navegador te pedirá confirmar el acceso directo.',
          )
        else ...[
          (
            '1. Abre el menú ⋮',
            'Arriba a la derecha en Chrome.',
          ),
          (
            '2. Instalar app',
            'Elige «Instalar app» o «Añadir a pantalla de inicio».',
          ),
        ],
        (
          canInstall ? '2. Ábrela desde el inicio' : '3. Ábrela desde el inicio',
          'Usa el icono de miProfio, no la pestaña del navegador.',
        ),
      ] else ...[
        (
          '1. Icono de instalar',
          'En la barra de direcciones (Chrome / Edge) pulsa el icono de instalar.',
        ),
        (
          '2. O desde el menú',
          'Menú → «Instalar miProfio.es».',
        ),
        (
          '3. Ábrela instalada',
          'Así los avisos funcionan mejor.',
        ),
      ],
    ];

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        alreadyIn
                            ? 'Ya tienes el acceso directo'
                            : 'Añade miProfio a tu inicio',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        alreadyIn
                            ? 'Abre la app desde el icono del inicio para recibir avisos.'
                            : 'Con el icono en el inicio, las notificaciones funcionan mucho mejor.',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      if (isIos && inApp && !alreadyIn) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.45),
                            ),
                          ),
                          child: const Text(
                            'Si estás en Gmail o WhatsApp, abre este enlace en Safari '
                            'para poder añadir a inicio.',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                      if (!alreadyIn) ...[
                        const SizedBox(height: 16),
                        for (final step in steps) ...[
                          Text(
                            step.$1,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.$2,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                      if (!alreadyIn && canInstall) ...[
                        FilledButton(
                          onPressed: () async {
                            final ok = await triggerAutoInstallPwa();
                            if (ok) await dismissPwaInstallPrompt();
                            onClose();
                          },
                          child: const Text('Instalar / Añadir a inicio'),
                        ),
                        const SizedBox(height: 4),
                      ],
                      TextButton(
                        onPressed: onClose,
                        child: Text(
                          alreadyIn || canInstall ? 'Cerrar' : 'Entendido',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Preferido: overlay in-page. Fallback a dialog si se llama sin overlay.
Future<void> showPwaHomeGuideDialog(BuildContext context) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: PwaHomeGuideOverlay(onClose: () => Navigator.pop(ctx)),
    ),
  );
}
