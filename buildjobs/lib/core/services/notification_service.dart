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

  // ── VAPID key para web push ──────────────────────────────────────────────
  // Cópiala desde Firebase Console → Project Settings → Cloud Messaging
  // → Web Push certificates → Key pair y ponla en .env como FIREBASE_VAPID_KEY
  static String get _vapidKey => dotenv.env['FIREBASE_VAPID_KEY'] ?? '';

  // ── Inicialización ───────────────────────────────────────────────────────

  /// Llama a este método una vez al arrancar la app (después de login).
  static Future<void> init() async {
    // Solicitar permiso (en web muestra el diálogo nativo del navegador)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] Permiso denegado');
      return;
    }

    debugPrint('[Push] Permiso: ${settings.authorizationStatus}');

    // Obtener token FCM del dispositivo/navegador
    await _refreshAndSaveToken();

    // Escuchar renovaciones de token (FCM rota el token periódicamente)
    _fcm.onTokenRefresh.listen(_saveToken);

    // ── Notificaciones en PRIMER PLANO ──────────────────────────────────
    // (el service worker solo gestiona las de background)
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      debugPrint('[Push] Mensaje en foreground: ${msg.notification?.title}');
      // En web, si la app está abierta, el Realtime ya actualiza el chat.
      // No mostramos notificación para no duplicar.
      // En móvil podríamos mostrar una local notification aquí si se añade
      // el paquete flutter_local_notifications.
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
