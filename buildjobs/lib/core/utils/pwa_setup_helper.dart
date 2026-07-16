import 'pwa_setup_helper_stub.dart'
    if (dart.library.html) 'pwa_setup_helper_web.dart' as impl;

import 'package:flutter/widgets.dart';

void initPwaSetupListener() => impl.initPwaSetupListener();

bool isIosWeb() => impl.isIosWeb();

bool isAndroidWeb() => impl.isAndroidWeb();

/// Navegador embebido (WhatsApp, Gmail, Instagram…): en iOS no se puede
/// «Añadir a inicio»; hay que abrir en Safari.
bool isInAppBrowser() => impl.isInAppBrowser();

bool isLikelyPrivateBrowsing() => impl.isLikelyPrivateBrowsing();

Future<void> ensureFirebaseMessagingSwReady() =>
    impl.ensureFirebaseMessagingSwReady();

void setPushServiceWorkerActive(bool active) =>
    impl.setPushServiceWorkerActive(active);

Future<void> unregisterPushServiceWorker() =>
    impl.unregisterPushServiceWorker();

Stream<void> get onPwaInstallPromptAvailable => impl.onPwaInstallPromptAvailable;

bool canAutoInstallPwa() => impl.canAutoInstallPwa();

Future<bool> triggerAutoInstallPwa() => impl.triggerAutoInstallPwa();

bool isStandalonePwa() => impl.isStandalonePwa();

bool lacksPwaDirectAccess() => impl.lacksPwaDirectAccess();

bool shouldShowIosInstallHint() => impl.shouldShowIosInstallHint();

bool shouldShowAndroidManualInstallHint() =>
    impl.shouldShowAndroidManualInstallHint();

bool shouldShowPwaInstallPrompt() => impl.shouldShowPwaInstallPrompt();

bool shouldShowPwaInstallOffer(BuildContext context) =>
    impl.shouldShowPwaInstallOffer(context);

bool shouldShowPwaInstallPromptInContext(BuildContext? context) =>
    impl.shouldShowPwaInstallPromptInContext(context);

bool isMobileWebBrowser() => impl.isMobileWebBrowser();

Future<bool> isPwaInstallPromptDismissed() =>
    impl.isPwaInstallPromptDismissed();

Future<void> dismissPwaInstallPrompt() => impl.dismissPwaInstallPrompt();

Future<void> snoozePwaInstallPrompt({Duration duration = const Duration(days: 2)}) =>
    impl.snoozePwaInstallPrompt(duration: duration);

void declinePwaInstallForSession() => impl.declinePwaInstallForSession();

Future<bool> isPwaSetupBannerDismissed() => isPwaInstallPromptDismissed();

Future<void> dismissPwaSetupBanner() => dismissPwaInstallPrompt();
