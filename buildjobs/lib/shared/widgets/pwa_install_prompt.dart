import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pwa_setup_helper.dart';

/// Tras iniciar sesión, espera unos segundos y ofrece el acceso directo si aún
/// no está instalado. Funciona en cualquier pantalla de la app.
class PwaInstallOfferListener extends ConsumerStatefulWidget {
  const PwaInstallOfferListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PwaInstallOfferListener> createState() =>
      _PwaInstallOfferListenerState();
}

class _PwaInstallOfferListenerState extends ConsumerState<PwaInstallOfferListener> {
  static const _offerDelay = Duration(seconds: 3);

  Timer? _delayTimer;
  String? _scheduledForUserId;
  String? _shownForUserId;

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  bool _isEligible(User user) {
    if (!kIsWeb || !lacksPwaDirectAccess()) return false;
    if (shouldShowPwaInstallPrompt()) return true;
    return shouldShowPwaInstallOffer(context);
  }

  void _cancelOffer() {
    _delayTimer?.cancel();
    _delayTimer = null;
    _scheduledForUserId = null;
  }

  void _scheduleOfferFor(User user) {
    if (!mounted || _shownForUserId == user.id) return;
    if (_scheduledForUserId == user.id) return;
    if (!_isEligible(user)) return;

    _scheduledForUserId = user.id;
    _delayTimer?.cancel();
    _delayTimer = Timer(_offerDelay, () {
      unawaited(_maybeOffer(user.id));
    });
  }

  Future<void> _maybeOffer(String userId) async {
    if (!mounted || _shownForUserId == userId) return;

    final user = ref.read(currentUserProvider);
    if (user == null || user.id != userId || !_isEligible(user)) return;
    if (await isPwaInstallPromptDismissed()) return;

    _shownForUserId = userId;
    await _showDialogWithRetry();
  }

  Future<void> _showDialogWithRetry() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (!mounted) return;

      final dialogContext = rootNavigatorKey.currentContext;
      if (dialogContext != null && dialogContext.mounted) {
        await PwaInstallSheets.showPrompt(dialogContext, autoOpened: true);
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  void _handleUserChange(User? prev, User? next) {
    if (next == null) {
      _cancelOffer();
      return;
    }

    if (prev?.id != next.id) {
      _scheduleOfferFor(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    ref.listen<User?>(currentUserProvider, _handleUserChange);

    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleOfferFor(user);
      });
    }

    return widget.child;
  }
}

/// Botón en AppBar de perfil.
class PwaInstallAppBarAction extends ConsumerStatefulWidget {
  const PwaInstallAppBarAction({super.key});

  @override
  ConsumerState<PwaInstallAppBarAction> createState() =>
      _PwaInstallAppBarActionState();
}

class _PwaInstallAppBarActionState extends ConsumerState<PwaInstallAppBarAction> {
  bool _dismissed = false;
  bool _checkedDismiss = false;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final dismissed = await isPwaInstallPromptDismissed();
    if (!mounted) return;
    setState(() {
      _dismissed = dismissed;
      _checkedDismiss = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (!_checkedDismiss ||
        _dismissed ||
        !kIsWeb ||
        user == null ||
        !lacksPwaDirectAccess()) {
      return const SizedBox.shrink();
    }
    if (!shouldShowPwaInstallOffer(context) && !shouldShowPwaInstallPrompt()) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'Añadir a inicio',
      icon: const Icon(Icons.add_to_home_screen_outlined),
      onPressed: () => PwaInstallSheets.showPrompt(context),
    );
  }
}

abstract final class PwaInstallSheets {
  PwaInstallSheets._();

  static Future<void> showPrompt(
    BuildContext context, {
    bool autoOpened = false,
  }) {
    if (!lacksPwaDirectAccess()) return Future.value();

    final dialogContext = rootNavigatorKey.currentContext ?? context;
    if (!dialogContext.mounted) return Future.value();

    return showDialog<void>(
      context: dialogContext,
      useRootNavigator: true,
      barrierDismissible: !autoOpened,
      builder: (ctx) => _InstallPromptDialog(autoOpened: autoOpened),
    );
  }

  static Future<void> showManualGuide(BuildContext context) =>
      _showManualGuide(context);

  static Future<void> _showManualGuide(BuildContext context) {
    final isIos = shouldShowIosInstallHint();

    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Text(
          'Cómo añadir ${AppConstants.appName} a tu inicio',
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
              Text(
                isIos
                    ? 'Pulsa Compartir en Safari y elige '
                        '«Añadir a pantalla de inicio». '
                        'Después ábrela desde el icono en tu inicio.'
                    : canAutoInstallPwa()
                        ? 'Pulsa el menú del navegador (⋮) y elige '
                            '«Instalar aplicación» o «Añadir a pantalla de inicio».'
                        : 'Pulsa el menú del navegador (⋮) y elige '
                            '«Añadir a pantalla de inicio».',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
              if (isIos) ...[
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
                  'Icono Compartir (cuadrado con flecha) abajo en Safari → '
                  '«Añadir a pantalla de inicio» → Añadir.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                const Text(
                  'Android (Chrome)',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Menú ⋮ arriba a la derecha → «Instalar aplicación» '
                  'o «Añadir a pantalla de inicio».',
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

class _InstallPromptDialog extends StatefulWidget {
  const _InstallPromptDialog({required this.autoOpened});

  final bool autoOpened;

  @override
  State<_InstallPromptDialog> createState() => _InstallPromptDialogState();
}

class _InstallPromptDialogState extends State<_InstallPromptDialog> {
  bool _busy = false;

  String get _primaryLabel {
    if (canAutoInstallPwa()) return 'Añadir a inicio';
    return 'Ver cómo añadir';
  }

  Future<void> _onLater() async {
    if (widget.autoOpened) {
      declinePwaInstallForSession();
    } else {
      await snoozePwaInstallPrompt();
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onPrimary() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (canAutoInstallPwa()) {
        final accepted = await triggerAutoInstallPwa();
        if (!mounted) return;
        Navigator.pop(context);
        if (accepted) {
          await dismissPwaInstallPrompt();
          unawaited(NotificationService.requestIfNeeded());
        }
        return;
      }

      if (!mounted) return;
      Navigator.pop(context);
      await PwaInstallSheets._showManualGuide(context);

      if (!lacksPwaDirectAccess()) {
        await dismissPwaInstallPrompt();
        unawaited(NotificationService.requestIfNeeded());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      title: const Row(
        children: [
          Icon(Icons.add_to_home_screen_rounded,
              color: AppTheme.primary, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Acceso directo en tu móvil',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Text(
          canAutoInstallPwa()
              ? 'Abre ${AppConstants.appName} como una app desde el icono de tu pantalla de '
                  'inicio. Pulsa «Añadir a inicio» cuando el navegador te lo '
                  'ofrezca.'
              : 'Abre ${AppConstants.appName} como una app desde el icono de tu pantalla de '
                  'inicio. Te explicamos en un paso cómo crear el acceso directo.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            height: 1.45,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _onLater,
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: _busy ? null : _onPrimary,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_primaryLabel),
        ),
      ],
    );
  }
}
