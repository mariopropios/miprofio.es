import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Diálogos y guía cuando el permiso de micrófono está denegado o bloqueado.
abstract final class MicPermissionHelper {
  /// Explica por qué se necesita el micrófono antes de pedir el permiso.
  static Future<bool> showPermissionRationale(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Row(
          children: [
            Icon(Icons.mic_rounded, color: AppTheme.primary, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Acceso al micrófono',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Para grabar mensajes de voz, necesitamos usar tu micrófono. '
            'Pulsa «Permitir» cuando el navegador o el sistema te lo solicite.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Guía para activar el micrófono cuando el permiso está bloqueado.
  static Future<void> showBlockedGuide(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Text(
          'Micrófono bloqueado',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No pudimos acceder al micrófono. Actívalo en los ajustes '
                'del navegador o del dispositivo y vuelve a intentarlo.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 16),
                const Text(
                  'iPhone (Safari)',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ajustes → Safari → Micrófono → Preguntar o Permitir.\n'
                  'O toca «aA» en la barra de direcciones → Configuración del '
                  'sitio web → Micrófono → Permitir.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Android (Chrome)',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Toca el candado junto a la URL → Permisos → Micrófono → Permitir.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
