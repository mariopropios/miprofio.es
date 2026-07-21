// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

/// Avisa a otras pestañas del mismo origen que el email ya está confirmado.
class EmailConfirmSync {
  EmailConfirmSync._();

  static const storageKey = 'profio_email_confirmed_v1';
  static const _channelName = 'profio_email_confirm';

  static html.BroadcastChannel? _channel;
  static void Function(html.Event)? _storageHandler;
  static void Function(EmailConfirmSignal)? _listener;

  static void notifyConfirmed({String? userId, String? dest}) {
    final payload = jsonEncode({
      'atMs': DateTime.now().millisecondsSinceEpoch,
      if (userId != null) 'userId': userId,
      if (dest != null) 'dest': dest,
    });
    try {
      // storage event solo se dispara en OTRAS pestañas.
      html.window.localStorage[storageKey] = payload;
    } catch (_) {}
    try {
      _channel ??= html.BroadcastChannel(_channelName);
      _channel!.postMessage(payload);
    } catch (_) {}
  }

  static void listen(void Function(EmailConfirmSignal signal) onSignal) {
    _listener = onSignal;
    try {
      _channel ??= html.BroadcastChannel(_channelName);
      _channel!.onMessage.listen((event) {
        final signal = _parse(event.data);
        if (signal != null) _listener?.call(signal);
      });
    } catch (_) {}

    _storageHandler = (html.Event event) {
      if (event is! html.StorageEvent) return;
      if (event.key != storageKey) return;
      final signal = _parse(event.newValue);
      if (signal != null) _listener?.call(signal);
    };
    html.window.addEventListener('storage', _storageHandler);
  }

  static void stopListening() {
    _listener = null;
    if (_storageHandler != null) {
      html.window.removeEventListener('storage', _storageHandler!);
      _storageHandler = null;
    }
  }

  static EmailConfirmSignal? readLatest() {
    try {
      return _parse(html.window.localStorage[storageKey]);
    } catch (_) {
      return null;
    }
  }

  static void clear() {
    try {
      html.window.localStorage.remove(storageKey);
    } catch (_) {}
  }

  static EmailConfirmSignal? _parse(Object? raw) {
    if (raw == null) return null;
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final atMs = (map['atMs'] as num?)?.toInt();
      if (atMs == null) return null;
      return EmailConfirmSignal(
        atMs: atMs,
        userId: map['userId']?.toString(),
        dest: map['dest']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

class EmailConfirmSignal {
  const EmailConfirmSignal({
    required this.atMs,
    this.userId,
    this.dest,
  });

  final int atMs;
  final String? userId;
  final String? dest;
}
