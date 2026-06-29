import 'dart:html' as html;

/// iPad real o emulación en Safari/Chrome DevTools.
bool isIpadLikeUserAgent() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  if (ua.contains('ipad')) return true;
  // iPadOS 13+ puede reportarse como Macintosh con touch.
  if (ua.contains('macintosh') &&
      (html.window.navigator.maxTouchPoints ?? 0) > 1) {
    return true;
  }
  return false;
}
