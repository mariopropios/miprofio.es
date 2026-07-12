import 'dart:async';

import 'package:flutter/widgets.dart';

bool canAutoInstallPwa() => false;

Stream<void> get onPwaInstallPromptAvailable => const Stream.empty();

Future<bool> triggerAutoInstallPwa() async => false;

bool isStandalonePwa() => false;

bool lacksPwaDirectAccess() => true;

bool shouldShowIosInstallHint() => false;

bool shouldShowAndroidManualInstallHint() => false;

bool shouldShowPwaInstallPrompt() => false;

bool shouldShowPwaInstallOffer(BuildContext context) => false;

bool shouldShowPwaInstallPromptInContext(BuildContext? context) => false;

bool isMobileWebBrowser() => false;

Future<bool> isPwaInstallPromptDismissed() async => false;

Future<void> dismissPwaInstallPrompt() async {}

void declinePwaInstallForSession() {}

Future<void> snoozePwaInstallPrompt({Duration duration = const Duration(days: 2)}) async {}

Future<bool> isPwaSetupBannerDismissed() async => false;

Future<void> dismissPwaSetupBanner() async {}

void initPwaSetupListener() {}
