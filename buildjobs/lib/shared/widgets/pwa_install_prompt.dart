import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/repository_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/push_setup_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pwa_setup_helper.dart';
import 'pwa_home_guide_dialog.dart';

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

enum _PwaGuidePlatform { ios, android, desktop }

_PwaGuidePlatform _detectPwaGuidePlatform() {
  if (isIosWeb()) return _PwaGuidePlatform.ios;
  if (isAndroidWeb()) return _PwaGuidePlatform.android;
  return _PwaGuidePlatform.desktop;
}

abstract final class PwaInstallSheets {
  PwaInstallSheets._();

  /// Oferta automática tras login (o botón de perfil).
  static Future<void> showPrompt(
    BuildContext context, {
    bool autoOpened = false,
  }) {
    if (!lacksPwaDirectAccess()) return Future.value();
    return showPwaHomeGuideDialog(context);
  }

  /// Campanita de Mensajes: siempre muestra contenido útil.
  static Future<void> showFromBell(BuildContext context) =>
      showPwaHomeGuideDialog(context);

  /// Guía manual (Perfil / tarjeta de notificaciones).
  static Future<void> showManualGuide(BuildContext context) =>
      showPwaHomeGuideDialog(context);

  static Future<void> _presentGuide(
    BuildContext context, {
    bool autoOpened = false,
  }) {
    return _present(
      context,
      barrierDismissible: !autoOpened,
      builder: (ctx) => _PwaInstallGuideSheet(autoOpened: autoOpened),
    );
  }

  /// Usa el context de la pantalla (como el diálogo vacío que sí abría).
  /// Fallback al Overlay del root navigator — nunca el Element del Navigator
  /// (falla en silencio dentro de ShellRoute).
  static Future<void> _present(
    BuildContext context, {
    required WidgetBuilder builder,
    bool barrierDismissible = true,
  }) async {
    final hosts = <BuildContext>[];

    if (context.mounted) hosts.add(context);

    final overlayCtx = rootNavigatorKey.currentState?.overlay?.context;
    if (overlayCtx != null && overlayCtx.mounted && !hosts.contains(overlayCtx)) {
      hosts.add(overlayCtx);
    }

    Object? lastError;
    for (final host in hosts) {
      if (!host.mounted) continue;
      try {
        await showDialog<void>(
          context: host,
          useRootNavigator: true,
          barrierDismissible: barrierDismissible,
          builder: (ctx) => Dialog(
            backgroundColor: AppTheme.surface,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: builder(ctx),
            ),
          ),
        );
        return;
      } catch (e, st) {
        lastError = e;
        debugPrint('[PWA] present guide failed: $e\n$st');
      }
    }

    debugPrint('[PWA] could not present guide. lastError=$lastError');
  }
}

class _PwaInstallGuideSheet extends StatefulWidget {
  const _PwaInstallGuideSheet({this.autoOpened = false});

  final bool autoOpened;

  @override
  State<_PwaInstallGuideSheet> createState() => _PwaInstallGuideSheetState();
}

class _PwaInstallGuideSheetState extends State<_PwaInstallGuideSheet> {
  bool _busy = false;
  late final _PwaGuidePlatform _platform = _detectPwaGuidePlatform();
  late final bool _inApp = isInAppBrowser();
  late final bool _canInstall = canAutoInstallPwa();

  List<_GuideStep> get _steps {
    switch (_platform) {
      case _PwaGuidePlatform.ios:
        return const [
          _GuideStep(
            Icons.ios_share_rounded,
            'Pulsa Compartir',
            'El icono del cuadrado con flecha, abajo en Safari.',
          ),
          _GuideStep(
            Icons.add_box_outlined,
            'Añadir a pantalla de inicio',
            'Desplázate en el menú y elige esa opción.',
          ),
          _GuideStep(
            Icons.check_circle_outline,
            'Pulsa Añadir',
            'Confirma y abre miProfio desde el icono nuevo.',
          ),
        ];
      case _PwaGuidePlatform.android:
        if (_canInstall) {
          return const [
            _GuideStep(
              Icons.download_rounded,
              'Pulsa Instalar',
              'El navegador te pedirá confirmar el acceso directo.',
            ),
            _GuideStep(
              Icons.home_outlined,
              'Ábrela desde el inicio',
              'Usa el icono de miProfio, no la pestaña del navegador.',
            ),
          ];
        }
        return const [
          _GuideStep(
            Icons.more_vert,
            'Abre el menú ⋮',
            'Arriba a la derecha en Chrome.',
          ),
          _GuideStep(
            Icons.install_mobile_outlined,
            'Instalar app',
            'Elige «Instalar app» o «Añadir a pantalla de inicio».',
          ),
          _GuideStep(
            Icons.home_outlined,
            'Ábrela desde el inicio',
            'Así las notificaciones funcionan mejor.',
          ),
        ];
      case _PwaGuidePlatform.desktop:
        if (_canInstall) {
          return const [
            _GuideStep(
              Icons.download_rounded,
              'Pulsa Instalar',
              'Confirma en el diálogo del navegador.',
            ),
            _GuideStep(
              Icons.desktop_windows_outlined,
              'Ábrela como app',
              'miProfio se abrirá en su propia ventana.',
            ),
          ];
        }
        return const [
          _GuideStep(
            Icons.install_desktop_outlined,
            'Icono de instalar',
            'En la barra de direcciones (Chrome / Edge), pulsa el icono ⊕ / PC.',
          ),
          _GuideStep(
            Icons.more_horiz,
            'O desde el menú',
            'Menú → «Instalar miProfio.es».',
          ),
          _GuideStep(
            Icons.open_in_new,
            'Ábrela instalada',
            'Así recibes avisos con más fiabilidad.',
          ),
        ];
    }
  }

  String get _primaryLabel {
    if (_canInstall) return 'Instalar / Añadir a inicio';
    if (_platform == _PwaGuidePlatform.ios) return 'Entendido';
    return 'Entendido';
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
      if (_canInstall) {
        final accepted = await triggerAutoInstallPwa();
        if (!mounted) return;
        Navigator.pop(context);
        if (accepted) {
          await dismissPwaInstallPrompt();
          unawaited(NotificationService.requestIfNeeded());
        }
        return;
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.add_to_home_screen_rounded,
                    color: AppTheme.primary, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Recibe avisos mejor con acceso directo',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Con el icono en el inicio, las notificaciones y el acceso '
              'funcionan mucho mejor.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (_platform == _PwaGuidePlatform.ios && _inApp) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.45),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Estás en un navegador embebido (p. ej. Gmail o WhatsApp). '
                        'Abre el enlace en Safari para poder añadir a inicio.',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _StepRow(index: i + 1, step: _steps[i]),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _onPrimary,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_primaryLabel),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _onLater,
              child: Text(widget.autoOpened ? 'Ahora no' : 'Más tarde'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.step});

  final int index;
  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(step.icon, size: 20, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                step.subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlreadyInstalledSheet extends StatefulWidget {
  const _AlreadyInstalledSheet();

  @override
  State<_AlreadyInstalledSheet> createState() => _AlreadyInstalledSheetState();
}

class _AlreadyInstalledSheetState extends State<_AlreadyInstalledSheet> {
  PushSetupState? _state;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = await NotificationService.evaluateSetupState();
    if (mounted) setState(() => _state = state);
  }

  Future<void> _activate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await NotificationService.activatePush();
      if (!mounted) return;
      setState(() => _state = result);
      final ok = result == PushSetupState.ready;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Notificaciones activadas'
                : result.description,
          ),
        ),
      );
      if (ok) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final state = _state;
    final needsPermission = state == PushSetupState.needsPermission ||
        state == PushSetupState.tokenSyncFailed;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.primary, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Ya tienes el acceso directo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state == PushSetupState.ready
                  ? 'Las notificaciones de mensajes están activas.'
                  : 'Abre miProfio desde el icono del inicio para recibir avisos.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            if (needsPermission) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy ? null : _activate,
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
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}
