import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/notification_service.dart';
import '../../core/services/push_setup_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pwa_setup_helper.dart';

/// Tarjeta de push en Perfil. Sin guía de acceso directo / PWA.
class PushNotificationSetupCard extends StatefulWidget {
  const PushNotificationSetupCard({super.key});

  @override
  State<PushNotificationSetupCard> createState() =>
      _PushNotificationSetupCardState();
}

class _PushNotificationSetupCardState extends State<PushNotificationSetupCard> {
  PushSetupState _state = PushSetupState.needsPermission;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!kIsWeb || !mounted) return;
    try {
      // iPhone Safari sin PWA: no insistir en instalar icono.
      if (isIosWeb() && !isStandalonePwa()) {
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
        return PushSetupState.needsPermission;
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
          _state = PushSetupState.needsPermission;
          _loaded = true;
        });
      }
    }
  }

  Future<void> _onPrimary() async {
    if (_busy) return;
    if (_state == PushSetupState.needsHomeScreenInstall) return;
    setState(() => _busy = true);
    try {
      final result = await NotificationService.activatePush();
      if (!mounted) return;
      setState(() => _state = result);
      final message = switch (result) {
        PushSetupState.ready => 'Notificaciones activadas correctamente',
        PushSetupState.permissionDenied =>
          'Permiso denegado. Actívalas en Ajustes',
        PushSetupState.tokenSyncFailed =>
          'No se pudo registrar el dispositivo. Inténtalo de nuevo',
        PushSetupState.privateBrowsing =>
          'No funcionan en modo privado. Usa Safari normal',
        PushSetupState.needsHomeScreenInstall =>
          'Notificaciones no disponibles en este navegador',
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
      return const SizedBox.shrink();
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
    final showButton = _state.showActivateButton ||
        (_state == PushSetupState.needsPermission && !_loaded);

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
                  : const Icon(Icons.notifications_active),
              label: const Text('Activar notificaciones'),
            ),
          ],
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

Future<void> showPushNotificationSetupDialog(BuildContext context) async {
  // Acceso directo / guía PWA desactivados.
}
