// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'cookie_consent_store.dart';

const _keyDecided = 'profio_cookie_consent_v1';
const _keyAnalytics = 'profio_cookie_analytics_v1';
const _keyMarketing = 'profio_cookie_marketing_v1';

CookieConsentPrefs readConsent() {
  try {
    final decided = html.window.localStorage[_keyDecided] == '1';
    if (!decided) return CookieConsentPrefs.undecided;
    return CookieConsentPrefs(
      decided: true,
      analytics: html.window.localStorage[_keyAnalytics] == '1',
      marketing: html.window.localStorage[_keyMarketing] == '1',
    );
  } catch (_) {
    return CookieConsentPrefs.undecided;
  }
}

Future<void> writeConsent(CookieConsentPrefs prefs) async {
  try {
    html.window.localStorage[_keyDecided] = prefs.decided ? '1' : '0';
    html.window.localStorage[_keyAnalytics] = prefs.analytics ? '1' : '0';
    html.window.localStorage[_keyMarketing] = prefs.marketing ? '1' : '0';
  } catch (_) {}
}
