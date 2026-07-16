import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/notification_service.dart';
import '../../core/services/push_setup_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pwa_setup_helper.dart';
import 'pwa_home_guide_dialog.dart';

/// Tarjeta de push en Perfil. Nunca debe tumbar el layout del perfil
/// (en release un ErrorWidget es un bloque gris enorme).
class PushNotificationSetupCard extends StatefulWidget {
  const PushNotificationSetupCard({super.key});

  @override
  State<PushNotificationSetupCard> createState() =>
      _PushNotificationSetupCardState();
}

class _PushNotificationSetupCardState extends State<PushNotificationSetupCard> {
  PushSetupState _state = PushSetupState.needsHomeScreenInstall;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    // Valor inicial seguro sin tocar JS helpers en el primer frame.
    if (kIsWeb) {
      _state = PushSetupState.needsHomeScreenInstall;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!kIsWeb || !mounted) return;
    try {
      final needsInstall = isIosWeb() && !isStandalonePwa();
      if (needsInstall) {
        if (mounted) {
          setState(() {
            _state = PushSetupState.needsHomeScreenInstall;
            _loaded = true;
          });
        }
        return;
      }
      final state = await NotificationService.evaluateSetupState()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        return isIosWeb()
            ? PushSetupState.needsHomeScreenInstall
            : PushSetupState.needsPermission;
      });
      if (mounted) {
        setState(() {
          _state = state;
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('[PushCard] refresh: $e');
      if (mounted) {
        setState(() {
          _state = PushSetupState.needsHomeScreenInstall;
          _loaded = true;
        });
      }
    }
  }

  Future<void> _onPrimary() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_state == PushSetupState.needsHomeScreenInstall) {
        await showPwaHomeGuideDialog(context);
        await _refresh();
        return;
      }
      final result = await NotificationService.activatePush();
      if (!mounted) return;
      setState(() => _state = result);
      final message = switch (result) {
        PushSetupState.ready => 'Notificaciones activadas correctamente',
        PushSetupState.permissionDenied =>
          'Permiso denegado. Actívalas en Ajustes del iPhone',
        PushSetupState.tokenSyncFailed =>
          'No se pudo registrar el dispositivo. Abre desde el icono del inicio',
        PushSetupState.privateBrowsing =>
          'No funcionan en modo privado. Usa la app desde el icono de inicio',
        PushSetupState.needsHomeScreenInstall =>
          'Primero añade la app a la pantalla de inicio',
        _ => 'No se pudieron activar las notificaciones',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      debugPrint('[PushCard] onPrimary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la acción')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    try {
      return _buildBody();
    } catch (e, st) {
      debugPrint('[PushCard] build failed: $e\n$st');
      return _fallbackCard();
    }
  }

  Widget _buildBody() {
    if (_state == PushSetupState.ready) {
      return _box(
        child: const Row(
          children: [
            Icon(Icons.notifications_active, color: AppTheme.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Notificaciones de mensajes activas',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final title = _state.title;
    final description = _state.description;
    final needsInstall = _state == PushSetupState.needsHomeScreenInstall;
    final showButton = _state.showActivateButton ||
        _state == PushSetupState.needsPermission ||
        !_loaded;

    return _box(
      warn: _state == PushSetupState.privateBrowsing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _state == PushSetupState.privateBrowsing
                    ? Icons.lock_outline
                    : Icons.notifications_outlined,
                color: _state == PushSetupState.privateBrowsing
                    ? Colors.orange
                    : AppTheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.4,
              fontSize: 14,
            ),
          ),
          if (showButton) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _onPrimary,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      needsInstall
                          ? Icons.add_to_home_screen
                          : Icons.notifications_active,
                    ),
              label: Text(
                needsInstall
                    ? 'Ver cómo añadir al inicio'
                    : 'Activar notificaciones',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fallbackCard() {
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Añade la app al inicio',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'En iPhone abre miProfio desde el icono de inicio para activar '
            'las notificaciones push (distinto de avisos por email).',
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.4,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => showPwaHomeGuideDialog(context),
            icon: const Icon(Icons.add_to_home_screen),
            label: const Text('Ver cómo añadir al inicio'),
          ),
        ],
      ),
    );
  }

  Widget _box({required Widget child, bool warn = false}) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: warn
                ? Colors.orange.withValues(alpha: 0.5)
                : AppTheme.primary.withValues(alpha: 0.35),
          ),
        ),
        child: child,
      ),
    );
  }
}

Future<void> showPushNotificationSetupDialog(BuildContext context) {
  return showPwaHomeGuideDialog(context);
}
