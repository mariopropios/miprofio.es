// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Coordina pestañas del mismo origin para deep links (emails).
///
/// Si ya hay otra pestaña viva de miProfio, le envía el destino y la pestaña
/// nueva puede cerrarse. Así no se acumulan 20 tabs al abrir notificaciones.
class TabCoordinator {
  TabCoordinator._();

  static const _channelName = 'profio_tab_coord_v1';
  static const _presenceKey = 'profio_tab_presence_v1';
  static const _handoffKey = 'profio_tab_handoff_v1';
  static const _presenceTtlMs = 8000;
  static const _heartbeatMs = 2500;
  static const _handoffWaitMs = 550;

  static final String tabId =
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 32)}';

  static html.BroadcastChannel? _channel;
  static Timer? _heartbeat;
  static StreamSubscription<html.MessageEvent>? _channelSub;
  static void Function(html.Event)? _storageHandler;
  static void Function(String targetPath)? _handoffListener;
  static bool _started = false;

  static void start() {
    if (_started) return;
    _started = true;
    try {
      _channel = html.BroadcastChannel(_channelName);
      _channelSub = _channel!.onMessage.listen(_onChannelMessage);
    } catch (e) {
      debugPrint('TabCoordinator channel: $e');
    }

    _storageHandler = (html.Event event) {
      if (event is! html.StorageEvent) return;
      if (event.key == _handoffKey && event.newValue != null) {
        _handleHandoffPayload(event.newValue);
      }
    };
    html.window.addEventListener('storage', _storageHandler);

    _touchPresence();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
      const Duration(milliseconds: _heartbeatMs),
      (_) => _touchPresence(),
    );

    html.window.addEventListener('pagehide', (_) => _removePresence());
    html.document.addEventListener('visibilitychange', (_) {
      if (html.document.visibilityState == 'visible') {
        _touchPresence();
      }
    });
  }

  static void stop() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _channelSub?.cancel();
    _channelSub = null;
    if (_storageHandler != null) {
      html.window.removeEventListener('storage', _storageHandler!);
      _storageHandler = null;
    }
    _removePresence();
    _started = false;
  }

  static void listenHandoffs(void Function(String targetPath) onHandoff) {
    start();
    _handoffListener = onHandoff;
  }

  static void stopListeningHandoffs() {
    _handoffListener = null;
  }

  static void closeWindowIfPossible() {
    try {
      html.window.close();
    } catch (_) {}
  }

  /// true si otra pestaña viva aceptó el destino.
  static Future<bool> tryHandoff(String targetPath) async {
    start();
    final target = _normalizeTarget(targetPath);
    if (target == null) return false;

    if (!_hasOtherLiveTab()) return false;

    final requestId =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    final payload = jsonEncode({
      'type': 'handoff',
      'requestId': requestId,
      'to': target,
      'fromTabId': tabId,
      'atMs': DateTime.now().millisecondsSinceEpoch,
    });

    var acked = false;
    StreamSubscription<html.MessageEvent>? sub;
    try {
      sub = _channel?.onMessage.listen((event) {
        final map = _asMap(event.data);
        if (map == null) return;
        if (map['type'] == 'handoff_ack' &&
            map['requestId']?.toString() == requestId) {
          acked = true;
        }
      });
    } catch (_) {}

    try {
      _channel?.postMessage(payload);
    } catch (_) {}
    try {
      html.window.localStorage[_handoffKey] = payload;
    } catch (_) {}

    final deadline =
        DateTime.now().add(const Duration(milliseconds: _handoffWaitMs));
    while (DateTime.now().isBefore(deadline)) {
      if (acked) break;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    await sub?.cancel();

    // Si no hubo ACK, esta pestaña navega sola (única abierta o listener viejo).
    return acked;
  }

  static void _onChannelMessage(html.MessageEvent event) {
    final map = _asMap(event.data);
    if (map == null) return;
    if (map['type'] == 'handoff') {
      _acceptHandoff(map);
    }
  }

  static void _handleHandoffPayload(Object? raw) {
    final map = _asMap(raw);
    if (map == null) return;
    if (map['type'] == 'handoff') {
      _acceptHandoff(map);
    }
  }

  static void _acceptHandoff(Map<String, dynamic> map) {
    final from = map['fromTabId']?.toString();
    if (from == null || from == tabId) return;
    final to = _normalizeTarget(map['to']?.toString());
    if (to == null) return;
    final requestId = map['requestId']?.toString();

    _handoffListener?.call(to);

    try {
      // ignore: avoid_dynamic_calls
      (html.window as dynamic).focus();
    } catch (_) {}

    if (requestId != null) {
      final ack = jsonEncode({
        'type': 'handoff_ack',
        'requestId': requestId,
        'tabId': tabId,
        'atMs': DateTime.now().millisecondsSinceEpoch,
      });
      try {
        _channel?.postMessage(ack);
      } catch (_) {}
    }
  }

  static bool _hasOtherLiveTab() {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final raw = html.window.localStorage[_presenceKey];
      if (raw == null || raw.isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final tabs = decoded['tabs'];
      if (tabs is! Map) return false;
      for (final entry in tabs.entries) {
        if (entry.key == tabId) continue;
        final last = (entry.value as num?)?.toInt() ?? 0;
        if (now - last <= _presenceTtlMs) return true;
      }
    } catch (_) {}
    return false;
  }

  static void _touchPresence() {
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final raw = html.window.localStorage[_presenceKey];
      Map<String, dynamic> tabs = {};
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['tabs'] is Map) {
          tabs = Map<String, dynamic>.from(decoded['tabs'] as Map);
        }
      }
      tabs.removeWhere((_, v) {
        final last = (v as num?)?.toInt() ?? 0;
        return now - last > _presenceTtlMs * 2;
      });
      tabs[tabId] = now;
      html.window.localStorage[_presenceKey] = jsonEncode({'tabs': tabs});
    } catch (_) {}
  }

  static void _removePresence() {
    try {
      final raw = html.window.localStorage[_presenceKey];
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['tabs'] is! Map) return;
      final tabs = Map<String, dynamic>.from(decoded['tabs'] as Map);
      tabs.remove(tabId);
      html.window.localStorage[_presenceKey] = jsonEncode({'tabs': tabs});
    } catch (_) {}
  }

  static String? _normalizeTarget(String? raw) {
    if (raw == null) return null;
    var t = raw.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('http://') || t.startsWith('https://')) {
      try {
        final u = Uri.parse(t);
        if (u.host.isNotEmpty &&
            u.host != html.window.location.hostname &&
            u.host != 'miprofio.es' &&
            u.host != 'www.miprofio.es') {
          return null;
        }
        t = u.hasQuery ? '${u.path}?${u.query}' : u.path;
      } catch (_) {
        return null;
      }
    }
    if (!t.startsWith('/')) t = '/$t';
    if (t.startsWith('/go')) return null;
    if (t.startsWith('//')) return null;
    return t;
  }

  static Map<String, dynamic>? _asMap(Object? raw) {
    if (raw == null) return null;
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
