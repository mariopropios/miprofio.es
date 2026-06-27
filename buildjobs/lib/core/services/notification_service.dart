import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestiona permisos de notificaciones push, obtiene el token FCM y
/// lo guarda en Supabase para que el servidor pueda enviar pushes.
class NotificationService {
  NotificationService._();

  static FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  static SupabaseClient get _db => Supabase.instance.client;
  static bool _listenersAttached = false;

  static bool get _firebaseReady => Firebase.apps.isNotEmpty;

  // ── VAPID key para web push ──────────────────────────────────────────────
  static String get _vapidKey => dotenv.env['FIREBASE_VAPID_KEY'] ?? '';

  /// Estado actual del permiso (sin pedirlo al usuario).
  static Future<AuthorizationStatus> permissionStatus() async {
    if (!_firebaseReady) return AuthorizationStatus.notDetermined;
    final settings = await _fcm.getNotificationSettings();
    return settings.authorizationStatus;
  }

  static Future<bool> get isEnabled async {
    final status = await permissionStatus();
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  /// Si el usuario ya concedió permiso antes, sincroniza token sin mostrar diálogo.
  static Future<void> syncIfAlreadyAuthorized() async {
    if (!_firebaseReady) return;
    if (!await isEnabled) return;
    await _ensureSetup();
  }

  /// Pide permiso solo al entrar en Mensajes si aún no está activo.
  static Future<bool> requestIfNeeded() async {
    if (!_firebaseReady) return false;

    final current = await permissionStatus();
    if (current == AuthorizationStatus.authorized ||
        current == AuthorizationStatus.provisional) {
      await _ensureSetup();
      return true;
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
    await _ensureSetup();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<void> _ensureSetup() async {
    await _refreshAndSaveToken();
    if (_listenersAttached) return;
    _listenersAttached = true;

    _fcm.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      debugPrint('[Push] Mensaje en foreground: ${msg.notification?.title}');
    });
  }

  // ── Token FCM ────────────────────────────────────────────────────────────

  static Future<void> _refreshAndSaveToken() async {
    try {
      final token = kIsWeb
          ? await _fcm.getToken(vapidKey: _vapidKey)
          : await _fcm.getToken();

      if (token != null) await _saveToken(token);
    } catch (e) {
      debugPrint('[Push] Error obteniendo token: $e');
    }
  }

  static Future<void> _saveToken(String token) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await _db
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', uid);
      debugPrint('[Push] Token FCM guardado en Supabase');
    } catch (e) {
      debugPrint('[Push] Error guardando token: $e');
    }
  }

  /// Borra el token al cerrar sesión para no recibir notificaciones
  /// mientras el usuario está desconectado.
  static Future<void> clearToken() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await _fcm.deleteToken();
      await _db
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', uid);
      debugPrint('[Push] Token FCM eliminado');
    } catch (e) {
      debugPrint('[Push] Error eliminando token: $e');
    }
  }
}
