// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _key = 'profio_post_email_confirm_path';

Future<void> persistPath(String path) async {
  try {
    html.window.localStorage[_key] = path;
  } catch (_) {}
}

Future<String?> loadPersistedPath() async {
  try {
    return html.window.localStorage[_key];
  } catch (_) {
    return null;
  }
}

Future<void> clearPersistedPath() async {
  try {
    html.window.localStorage.remove(_key);
  } catch (_) {}
}
