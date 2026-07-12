import 'push_notification_clear_stub.dart'
    if (dart.library.html) 'push_notification_clear_web.dart' as impl;

Future<void> clearGroupedChatNotifications(String conversationId) =>
    impl.clearGroupedChatNotifications(conversationId);

Future<void> updatePushBadgeCount(int unreadCount) =>
    impl.updatePushBadgeCount(unreadCount);
