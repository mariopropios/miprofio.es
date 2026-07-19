import '../router/routes.dart';

/// Detecta URLs de retorno de Supabase (confirmación de email, OAuth, etc.).
class AuthCallbackService {
  AuthCallbackService._();

  /// Parámetros en query y fragment (#) — Supabase puede usar ambos.
  static Map<String, String> allParameters(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);
    if (uri.fragment.isNotEmpty) {
      params.addAll(Uri.splitQueryString(uri.fragment));
    }
    return params;
  }

  static bool isAuthCallback(Uri uri) {
    final params = allParameters(uri);
    if (params.containsKey('code')) return true;
    if (params.containsKey('token_hash')) return true;
    if (params.containsKey('error') ||
        params.containsKey('error_description')) {
      return true;
    }
    if (params.containsKey('access_token') ||
        params.containsKey('refresh_token')) {
      return true;
    }
    return false;
  }

  static String? recoveryTokenHash(Uri uri) => allParameters(uri)['token_hash'];

  /// Destino tras confirmar email en web (debe estar en Redirect URLs de Supabase).
  static String webEmailRedirectTo() {
    return '${Uri.base.origin}${AppRoutes.profileAfterEmailVerification()}';
  }

  /// Destino del enlace de recuperación de contraseña (Redirect URLs de Supabase).
  ///
  /// Usa el origen actual (workers.dev o miprofio.es) para que el email
  /// redirija al mismo sitio desde el que se pidió el reset.
  static String webPasswordResetRedirectTo() {
    final origin = Uri.base.origin;
    if (origin.isNotEmpty && origin != 'null' && origin.startsWith('http')) {
      return '$origin${AppRoutes.resetPassword}';
    }
    return 'https://profio-web.mariopropiosplaza.workers.dev${AppRoutes.resetPassword}';
  }

  static bool isPasswordRecoveryCallback(Uri uri) {
    return allParameters(uri)['type'] == 'recovery';
  }
}
