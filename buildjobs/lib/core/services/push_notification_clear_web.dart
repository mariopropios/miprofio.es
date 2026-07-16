// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

const _swTimeout = Duration(seconds: 2);

Future<void> clearGroupedChatNotifications(String conversationId) async {
  final tag = 'chat-$conversationId';

  await _closeNotificationsWithTag(tag);
  await _postClearToServiceWorker(conversationId);

  // Reintento: el SW puede no estar listo en el primer frame.
  unawaited(Future<void>.delayed(const Duration(milliseconds: 250), () async {
    await _closeNotificationsWithTag(tag);
    await _postClearToServiceWorker(conversationId);
  }));
}

Future<void> updatePushBadgeCount(int unreadCount) async {
  try {
    final nav = html.window.navigator as dynamic;
    if (unreadCount <= 0) {
      final clearBadge = nav.clearAppBadge;
      if (clearBadge != null) {
        await clearBadge.call();
      }
      return;
    }

    final setBadge = nav.setAppBadge;
    if (setBadge != null) {
      await setBadge.call(unreadCount);
    }
  } catch (_) {}
}

Future<html.ServiceWorkerRegistration?> _serviceWorkerReady() async {
  final sw = html.window.navigator.serviceWorker;
  if (sw == null) return null;
  try {
    return await sw.ready.timeout(_swTimeout);
  } catch (_) {
    return null;
  }
}

Future<void> _closeNotificationsWithTag(String tag) async {
  final reg = await _serviceWorkerReady();
  if (reg == null) return;

  try {
    final notifications = await reg.getNotifications({'tag': tag});
    for (final notification in notifications) {
      notification.close();
    }

    // Fallback: algunos navegadores no filtran bien por tag.
    final all = await reg.getNotifications();
    for (final notification in all) {
      if (notification.tag == tag) notification.close();
    }
  } catch (_) {}
}

Future<void> _postClearToServiceWorker(String conversationId) async {
  final sw = html.window.navigator.serviceWorker;
  if (sw == null) return;

  final payload = {
    'type': 'CLEAR_CHAT_NOTIFICATIONS',
    'conversationId': conversationId,
  };

  try {
    final reg = await _serviceWorkerReady();
    reg?.active?.postMessage(payload);
    sw.controller?.postMessage(payload);
  } catch (_) {}
}
