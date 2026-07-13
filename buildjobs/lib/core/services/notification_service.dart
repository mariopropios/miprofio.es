import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../router/routes.dart';
import '../utils/pwa_setup_helper.dart';
import 'push_notification_clear.dart';
import 'push_setup_state.dart';

/// Gestiona permisos de notificaciones push, obtiene el token FCM y
/// lo guarda en Supabase para que el servidor pueda enviar pushes.
class NotificationService {
  NotificationService._();

  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  static SupabaseClient get _db => Supabase.instance.client;
  static bool _listenersAttached = false;
  static GoRouter? _router;

  static bool get _firebaseReady => Firebase.apps.isNotEmpty;

  // ── VAPID key para web push ──────────────────────────────────────────────
  static String get _vapidKey => dotenv.env['FIREBASE_VAPID_KEY'] ?? '';

  static bool _webPushPrepared = false;

  /// Estado actual del permiso (sin pedirlo al usuario).
  static Future<AuthorizationStatus> permissionStatus() async {
    if (!_firebaseReady) return AuthorizationStatus.notDetermined;
    try {
      final settings = await _fcm.getNotificationSettings();
      return settings.authorizationStatus;
    } catch (e) {
      debugPrint('[Push] Error leyendo permiso: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  static Future<bool> get isEnabled async {
    final status = await permissionStatus();
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  /// Enlaza el router para abrir el chat al pulsar una notificación.
  static void attachRouter(GoRouter router) {
    _router = router;
    _attachMessageListeners();
    _handleInitialMessage();
  }

  /// Si el usuario ya concedió permiso antes, sincroniza token sin mostrar diálogo.
  static Future<void> syncIfAlreadyAuthorized() async {
    if (!_firebaseReady) return;
    if (kIsWeb && isLikelyPrivateBrowsing()) return;
    if (kIsWeb && isIosWeb() && !isStandalonePwa()) return;
    if (!await isEnabled) return;
    _scheduleSetup();
  }

  /// Evalúa qué falta para recibir push en este dispositivo.
  static Future<PushSetupState> evaluateSetupState() async {
    if (!_firebaseReady) return PushSetupState.firebaseMissing;
    if (kIsWeb && isLikelyPrivateBrowsing()) {
      return PushSetupState.privateBrowsing;
    }
    if (kIsWeb && isIosWeb() && !isStandalonePwa()) {
      return PushSetupState.needsHomeScreenInstall;
    }

    final status = await permissionStatus();
    if (status == AuthorizationStatus.denied) {
      return PushSetupState.permissionDenied;
    }
    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      if (await _hasValidTokenInProfile()) {
        return PushSetupState.ready;
      }
      return PushSetupState.tokenSyncFailed;
    }
    return PushSetupState.needsPermission;
  }

  /// Activa push tras comprobar requisitos (gesto del usuario).
  static Future<PushSetupState> activatePush() async {
    var state = await evaluateSetupState();
    if (state == PushSetupState.ready) {
      await _ensureSetup();
      return await _hasValidTokenInProfile()
          ? PushSetupState.ready
          : PushSetupState.tokenSyncFailed;
    }
    if (state != PushSetupState.needsPermission &&
        state != PushSetupState.tokenSyncFailed) {
      return state;
    }

    final granted = await requestIfNeeded();
    if (!granted) {
      final after = await permissionStatus();
      if (after == AuthorizationStatus.denied) {
        return PushSetupState.permissionDenied;
      }
      return PushSetupState.needsPermission;
    }

    await _ensureSetup();
    state = await evaluateSetupState();
    return state == PushSetupState.tokenSyncFailed
        ? PushSetupState.tokenSyncFailed
        : (await _hasValidTokenInProfile()
            ? PushSetupState.ready
            : PushSetupState.tokenSyncFailed);
  }

  /// Pide permiso si aún no está activo (p. ej. tras iniciar sesión).
  /// No bloquea la UI esperando el token FCM: eso se sincroniza en segundo plano.
  static Future<bool> requestIfNeeded() async {
    if (!_firebaseReady) return false;

    final current = await permissionStatus();
    if (current == AuthorizationStatus.authorized ||
        current == AuthorizationStatus.provisional) {
      _scheduleSetup();
      return true;
    }

    if (current == AuthorizationStatus.denied) {
      debugPrint('[Push] Permiso denegado previamente');
      return false;
    }

    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] Permiso denegado');
      return false;
    }

    debugPrint('[Push] Permiso: ${settings.authorizationStatus}');
    _scheduleSetup();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static bool _setupScheduled = false;

  static void _scheduleSetup() {
    if (_setupScheduled) return;
    _setupScheduled = true;
    Future<void>(() async {
      try {
        await _ensureSetup();
      } finally {
        _setupScheduled = false;
      }
    });
  }

  static Future<void> _ensureSetup() async {
    if (kIsWeb && !_webPushPrepared) {
      _webPushPrepared = true;
      await ensureFirebaseMessagingSwReady();
    }
    await _refreshAndSaveToken();
    _attachMessageListeners();
  }

  static void _attachMessageListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    _fcm.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      debugPrint('[Push] Mensaje en foreground: ${msg.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);
  }

  static Future<void> _handleInitialMessage() async {
    if (!_firebaseReady) return;
    try {
      final initial = await _fcm.getInitialMessage();
      if (initial != null) {
        // Esperar a que Flutter termine de montar el router.
        await Future.delayed(const Duration(milliseconds: 600));
        _navigateFromMessage(initial);
      }
    } catch (e) {
      debugPrint('[Push] Error leyendo mensaje inicial: $e');
    }
  }

  static void _navigateFromMessage(RemoteMessage msg) {
    final router = _router;
    if (router == null) return;

    final professionalId = msg.data['professional_id'];
    if (professionalId == null || professionalId.isEmpty) return;

    final conversationId = msg.data['conversation_id'];
    final senderName = msg.data['sender_name'];

    router.push(
      AppRoutes.chatPath(professionalId),
      extra: {
        if (conversationId != null) 'conversationId': conversationId,
        if (senderName != null && senderName.isNotEmpty) 'name': senderName,
      },
    );
  }

  // ── Token FCM ────────────────────────────────────────────────────────────

  static String _fcmPlatformLabel() {
    if (!kIsWeb) return 'native';
    if (isIosWeb() && isStandalonePwa()) return 'web_ios';
    if (isAndroidWeb() && isStandalonePwa()) return 'web_android';
    return 'web';
  }

  static Future<bool> _hasValidTokenInProfile() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return false;

    try {
      final row = await _db
          .from('profiles')
          .select('fcm_token, fcm_platform')
          .eq('id', uid)
          .maybeSingle();
      final token = row?['fcm_token'] as String?;
      if (token == null || token.isEmpty) return false;

      if (kIsWeb && isIosWeb() && isStandalonePwa()) {
        final platform = row?['fcm_platform'] as String?;
        return platform == 'web_ios';
      }
      return true;
    } catch (e) {
      debugPrint('[Push] Error leyendo token en perfil: $e');
      return false;
    }
  }

  static Future<void> _refreshAndSaveToken() async {
    try {
      final Future<String?> tokenFuture = kIsWeb
          ? _fcm.getToken(vapidKey: _vapidKey)
          : _fcm.getToken();

      final token = await tokenFuture.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[Push] getToken timeout (la app sigue usable)');
          return null;
        },
      );

      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('[Push] Error obteniendo token: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;

    if (kIsWeb && isLikelyPrivateBrowsing()) {
      debugPrint('[Push] Modo privado: no guardamos token');
      return;
    }
    if (kIsWeb && isIosWeb() && !isStandalonePwa()) {
      debugPrint('[Push] iOS sin PWA instalada: no guardamos token');
      return;
    }

    try {
      await _db
          .from('profiles')
          .update({
            'fcm_token': token,
            'fcm_platform': _fcmPlatformLabel(),
          })
          .eq('id', uid);
      debugPrint('[Push] Token FCM guardado en Supabase');
    } catch (e) {
      debugPrint('[Push] Error guardando token (con plataforma): $e');
      try {
        await _db
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', uid);
        debugPrint('[Push] Token FCM guardado (sin plataforma)');
      } catch (e2) {
        debugPrint('[Push] Error guardando token: $e2');
      }
    }
  }

  static Future<void> clearGroupedChat(String conversationId) =>
      clearGroupedChatNotifications(conversationId);

  /// Borra el token al cerrar sesión para no recibir notificaciones
  /// mientras el usuario está desconectado.
  static Future<void> clearToken() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await _fcm.deleteToken();
      await _db
          .from('profiles')
          .update({'fcm_token': null, 'fcm_platform': null})
          .eq('id', uid);
      debugPrint('[Push] Token FCM eliminado');
    } catch (e) {
      debugPrint('[Push] Error eliminando token: $e');
    }
  }
}
