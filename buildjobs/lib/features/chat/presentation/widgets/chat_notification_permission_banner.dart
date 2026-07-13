import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/pwa_setup_helper.dart';

/// Banner para activar notificaciones en iPhone (requiere gesto del usuario).
class ChatNotificationPermissionBanner extends StatefulWidget {
  const ChatNotificationPermissionBanner({super.key});

  @override
  State<ChatNotificationPermissionBanner> createState() =>
      _ChatNotificationPermissionBannerState();
}

class _ChatNotificationPermissionBannerState
    extends State<ChatNotificationPermissionBanner> {
  AuthorizationStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    try {
      final status = await NotificationService.permissionStatus();
      if (mounted) setState(() => _status = status);
    } catch (e) {
      debugPrint('[Push] Banner permiso: $e');
    }
  }

  Future<void> _activate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await NotificationService.activatePush();
      await _refreshStatus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _shouldShow {
    if (!kIsWeb || !isStandalonePwa() || !isIosWeb()) return false;
    final status = _status;
    if (status == null) return false;
    return status != AuthorizationStatus.authorized &&
        status != AuthorizationStatus.provisional;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();

    final denied = _status == AuthorizationStatus.denied;

    return Material(
      color: const Color(0xFF1A2329),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notifications_active_outlined,
                color: AppTheme.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activa las notificaciones',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    denied
                        ? 'Ve a Ajustes → miProfio.es → Notificaciones y actívalas.'
                        : 'Recibe avisos cuando te escriban, aunque no tengas la app abierta.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (!denied) ...[
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _activate,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(72, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Activar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
