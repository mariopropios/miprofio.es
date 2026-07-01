import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/app_theme.dart';
import 'geo_service.dart';

/// Diálogos y acciones cuando el permiso de ubicación está bloqueado.
abstract final class GeoPermissionHelper {
  /// Muestra guía si el permiso está bloqueado; en nativo abre ajustes.
  static Future<void> handleException(
    BuildContext context,
    GeoServiceException error,
  ) async {
    if (!context.mounted) return;

    if (error.failure == GeoServiceFailure.permissionBlocked && !kIsWeb) {
      await Geolocator.openAppSettings();
      return;
    }

    if (error.failure == GeoServiceFailure.permissionBlocked) {
      await showBlockedGuide(context);
    }
  }

  static Future<void> showBlockedGuide(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Text(
          'Activar ubicación',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'El navegador tiene bloqueado el acceso a tu ubicación. '
                'Para usar «Cerca de mí», actívalo y vuelve a pulsar el botón.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'iPhone (Safari)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Ajustes → Safari → Ubicación → Preguntar o Permitir.\n'
                'O toca «aA» en la barra de direcciones → Configuración del sitio web → Ubicación → Permitir.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Android (Chrome)',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Toca el candado junto a la URL → Permisos → Ubicación → Permitir.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.45,
                  fontSize: 13,
                ),
              ),
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
