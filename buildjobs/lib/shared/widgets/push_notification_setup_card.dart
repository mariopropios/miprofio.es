import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/notification_service.dart';
import '../../core/services/push_setup_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pwa_setup_helper.dart';
import 'pwa_install_prompt.dart';

/// Tarjeta en Perfil para configurar notificaciones de mensajes (iOS PWA).
class PushNotificationSetupCard extends StatefulWidget {
  const PushNotificationSetupCard({super.key});

  @override
  State<PushNotificationSetupCard> createState() =>
      _PushNotificationSetupCardState();
}

class _PushNotificationSetupCardState extends State<PushNotificationSetupCard> {
  PushSetupState? _state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final state = await NotificationService.evaluateSetupState();
    if (mounted) setState(() => _state = state);
  }

  Future<void> _onPrimary() async {
    if (_busy || _state == null) return;
    setState(() => _busy = true);
    try {
      if (_state == PushSetupState.needsHomeScreenInstall) {
        await PwaInstallSheets.showManualGuide(context);
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final state = _state;
    if (state == null) {
      return const SizedBox.shrink();
    }

    if (state == PushSetupState.ready) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
        ),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: state == PushSetupState.privateBrowsing
              ? Colors.orange.withValues(alpha: 0.5)
              : AppTheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state == PushSetupState.privateBrowsing
                    ? Icons.lock_outline
                    : Icons.notifications_outlined,
                color: state == PushSetupState.privateBrowsing
                    ? Colors.orange
                    : AppTheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
          ),
          if (state.showActivateButton ||
              state == PushSetupState.needsPermission) ...[
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
                      state == PushSetupState.needsHomeScreenInstall
                          ? Icons.add_to_home_screen
                          : Icons.notifications_active,
                    ),
              label: Text(
                state == PushSetupState.needsHomeScreenInstall
                    ? 'Ver cómo añadir al inicio'
                    : 'Activar notificaciones',
              ),
            ),
          ],
          if (isIosWeb() && state == PushSetupState.privateBrowsing) ...[
            const SizedBox(height: 8),
            Text(
              'Requisitos iPhone: iOS 16.4+, app en pantalla de inicio, '
              'sin modo privado.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Diálogo rápido (desde icono en Mensajes).
Future<void> showPushNotificationSetupDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: const Text('Notificaciones de mensajes'),
      content: const SingleChildScrollView(
        child: PushNotificationSetupCard(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
