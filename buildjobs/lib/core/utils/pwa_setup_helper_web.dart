// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

import 'package:flutter/widgets.dart';

const _snoozeKey = 'profio_pwa_install_v6_snooze_until';
const _installedKey = 'profio_pwa_install_v6_installed';

bool _declinedThisSession = false;

dynamic _deferredInstallPrompt;
final _installPromptController = StreamController<void>.broadcast();

/// Se dispara cuando el navegador ofrece instalación automática (Android).
Stream<void> get onPwaInstallPromptAvailable =>
    _installPromptController.stream;

void _captureInstallPrompt(dynamic event) {
  try {
    event.preventDefault();
  } catch (_) {}
  _deferredInstallPrompt = event;
  try {
    (html.window as dynamic).__deferredPwaPrompt = event;
  } catch (_) {}
  _installPromptController.add(null);
}

void _syncPromptFromWindow() {
  try {
    final existing = (html.window as dynamic).__deferredPwaPrompt;
    if (existing != null) {
      _deferredInstallPrompt = existing;
      _installPromptController.add(null);
    }
  } catch (_) {}
}

void initPwaSetupListener() {
  _syncPromptFromWindow();

  html.window.addEventListener('beforeinstallprompt', _captureInstallPrompt);
  html.window.addEventListener('pwa-install-available', (_) {
    _syncPromptFromWindow();
  });
  html.window.addEventListener('appinstalled', (_) {
    _deferredInstallPrompt = null;
    _installPromptController.add(null);
    unawaited(dismissPwaInstallPrompt());
  });
}

bool canAutoInstallPwa() => _deferredInstallPrompt != null;

Future<bool> triggerAutoInstallPwa() async {
  final prompt = _deferredInstallPrompt;
  if (prompt == null) return false;

  try {
    final dynamic p = prompt;
    p.prompt();
    final choice = await p.userChoice;
    _deferredInstallPrompt = null;
    try {
      (html.window as dynamic).__deferredPwaPrompt = null;
    } catch (_) {}
    return choice.outcome == 'accepted';
  } catch (_) {
    return false;
  }
}

bool _isIosDevice() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod');
}

bool _isAndroidDevice() {
  return html.window.navigator.userAgent.toLowerCase().contains('android');
}

bool isIosWeb() {
  try {
    return _isIosDevice();
  } catch (_) {
    return false;
  }
}

bool isAndroidWeb() {
  try {
    return _isAndroidDevice();
  } catch (_) {
    return false;
  }
}

/// Chrome Custom Tabs / WebViews de apps (WhatsApp, Gmail, Instagram, etc.).
bool isInAppBrowser() {
  try {
    final ua = html.window.navigator.userAgent.toLowerCase();
    const markers = [
      'wv',
      'fbav',
      'fban',
      'instagram',
      'line/',
      'whatsapp',
      'twitter',
      'linkedin',
      'gsa/',
      'gmail',
      'yahoo',
      'micromessenger',
    ];
    for (final m in markers) {
      if (ua.contains(m)) return true;
    }
    if (_isIosDevice() &&
        !ua.contains('safari') &&
        !ua.contains('crios') &&
        !ua.contains('fxios') &&
        !ua.contains('edgios')) {
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

bool isLikelyPrivateBrowsing() {
  try {
    html.window.localStorage['__profio_priv_test'] = '1';
    html.window.localStorage.remove('__profio_priv_test');
    return false;
  } catch (_) {
    return true;
  }
}

Future<void> ensureFirebaseMessagingSwReady() async {
  try {
    final sw = html.window.navigator.serviceWorker;
    if (sw == null) return;

    final existing = await sw.getRegistration('/');
    if (existing?.active != null) {
      setPushServiceWorkerActive(true);
      return;
    }

    final registerFn = (html.window as dynamic).profioRegisterFirebaseMessagingSw;
    if (registerFn != null) {
      await registerFn().timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );
    }
    // No await sw.ready sin SW: en iOS puede colgarse indefinidamente.
    await sw.ready.timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('[PWA] FCM service worker: $e');
  }
}

void setPushServiceWorkerActive(bool active) {
  try {
    final fn = (html.window as dynamic).profioSetPushServiceWorkerActive;
    if (fn != null) fn(active);
  } catch (_) {}
}

Future<void> unregisterPushServiceWorker() async {
  try {
    final fn = (html.window as dynamic).profioUnregisterFirebaseMessagingSw;
    if (fn != null) await fn();
  } catch (e) {
    debugPrint('[PWA] unregister push SW: $e');
  }
}

bool isStandalonePwa() {
  try {
    return html.window.matchMedia('(display-mode: standalone)').matches ||
        html.window.matchMedia('(display-mode: fullscreen)').matches ||
        (html.window.navigator as dynamic).standalone == true;
  } catch (_) {
    return false;
  }
}

/// True si el usuario aún no abre Profio como acceso directo / PWA instalada.
bool lacksPwaDirectAccess() => !isStandalonePwa();

bool shouldShowIosInstallHint() => false;

bool shouldShowAndroidManualInstallHint() => false;

bool isMobileWebBrowser() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  if (ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod') ||
      ua.contains('android')) {
    return true;
  }
  if (ua.contains('mobile')) return true;
  if (ua.contains('whatsapp')) return true;

  try {
    final uaData = (html.window.navigator as dynamic).userAgentData;
    if (uaData != null && uaData.mobile == true) return true;
  } catch (_) {}

  if (html.window.matchMedia('(pointer: coarse)').matches &&
      !html.window.matchMedia('(pointer: fine)').matches) {
    return true;
  }

  return false;
}

/// Ofertas de acceso directo / PWA desactivadas (rompían el arranque web).
bool shouldShowPwaInstallPrompt() => false;

/// Oferta de instalación desactivada.
bool shouldShowPwaInstallOffer(BuildContext context) => false;

bool shouldShowPwaInstallPromptInContext(BuildContext? context) => false;

Future<bool> isPwaInstallPromptDismissed() async {
  if (isStandalonePwa() || _declinedThisSession) return true;

  try {
    if (html.window.localStorage[_installedKey] == '1') return true;

    final snoozeUntil =
        int.tryParse(html.window.localStorage[_snoozeKey] ?? '') ?? 0;
    return DateTime.now().millisecondsSinceEpoch < snoozeUntil;
  } catch (_) {
    return false;
  }
}

void declinePwaInstallForSession() {
  _declinedThisSession = true;
}

Future<void> snoozePwaInstallPrompt({
  Duration duration = const Duration(days: 2),
}) async {
  declinePwaInstallForSession();
  try {
    final until = DateTime.now().add(duration).millisecondsSinceEpoch;
    html.window.localStorage[_snoozeKey] = '$until';
  } catch (_) {}
}

Future<void> dismissPwaInstallPrompt() async {
  try {
    html.window.localStorage[_installedKey] = '1';
    html.window.localStorage.remove(_snoozeKey);
  } catch (_) {}
}

@Deprecated('Use isPwaInstallPromptDismissed')
Future<bool> isPwaSetupBannerDismissed() => isPwaInstallPromptDismissed();

@Deprecated('Use dismissPwaInstallPrompt')
Future<void> dismissPwaSetupBanner() => dismissPwaInstallPrompt();
