// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:flutter/services.dart';

import 'profile_share.dart';

Future<ProfileShareOutcome> shareProfileLink({
  required String url,
  required String text,
  String title = 'miProfio.es',
}) async {
  // Solo `text` (ya incluye la URL). Pasar también `url` duplica el enlace
  // en WhatsApp iOS.
  try {
    await html.window.navigator.share({
      'title': title,
      'text': text,
    });
    return ProfileShareOutcome.shared;
  } on html.DomException catch (e) {
    if (e.name == 'AbortError') {
      return ProfileShareOutcome.cancelled;
    }
  } catch (_) {}

  try {
    final wa = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(text)}',
    );
    html.window.open(wa.toString(), '_blank');
    return ProfileShareOutcome.openedWhatsApp;
  } catch (_) {}

  try {
    await Clipboard.setData(ClipboardData(text: text));
    return ProfileShareOutcome.copied;
  } catch (_) {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      return ProfileShareOutcome.copied;
    } catch (_) {
      return ProfileShareOutcome.failed;
    }
  }
}
