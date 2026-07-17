import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'profile_share.dart';

Future<ProfileShareOutcome> shareProfileLink({
  required String url,
  required String text,
  String title = 'miProfio.es',
}) async {
  try {
    final wa = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(text)}',
    );
    if (await canLaunchUrl(wa)) {
      final ok = await launchUrl(wa, mode: LaunchMode.externalApplication);
      if (ok) return ProfileShareOutcome.openedWhatsApp;
    }
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
