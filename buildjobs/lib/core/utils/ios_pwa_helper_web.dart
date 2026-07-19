// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _dismissKey = 'profio_ios_pwa_banner_dismissed';

bool _isIosDevice() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod');
}

bool _isStandalonePwa() {
  return html.window.matchMedia('(display-mode: standalone)').matches ||
      html.window.matchMedia('(display-mode: fullscreen)').matches;
}

bool shouldShowIosPwaInstallBanner() => false;

Future<bool> isIosPwaBannerDismissed() async {
  try {
    return html.window.localStorage[_dismissKey] == '1';
  } catch (_) {
    return false;
  }
}

Future<void> dismissIosPwaBanner() async {
  try {
    html.window.localStorage[_dismissKey] = '1';
  } catch (_) {}
}
