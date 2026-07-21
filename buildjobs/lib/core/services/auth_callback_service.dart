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

  /// Tipo de OTP en el enlace (`signup`, `email`, `recovery`, …).
  static String? authCallbackType(Uri uri) =>
      allParameters(uri)['type']?.toLowerCase();

  static bool isEmailConfirmationCallback(Uri uri) {
    final type = authCallbackType(uri);
    return recoveryTokenHash(uri) != null &&
        (type == 'signup' || type == 'email' || type == 'invite');
  }

  /// Destino tras confirmar email en web (debe estar en Redirect URLs de Supabase).
  ///
  /// Sin query (`?verified=…`): si la plantilla usa RedirectTo + token_hash,
  /// un `?` extra no rompe la URL. La UI de “email verificado” la pone el router.
  static String webEmailRedirectTo() {
    final origin = Uri.base.origin;
    const path = AppRoutes.authConfirm;
    if (origin.isNotEmpty && origin != 'null' && origin.startsWith('http')) {
      return '$origin$path';
    }
    return 'https://miprofio.es$path';
  }

  /// Destino del enlace de recuperación de contraseña (Redirect URLs de Supabase).
  /// Preferir miprofio.es (workers.dev redirige y Chrome lo trata como spam en push).
  static String webPasswordResetRedirectTo() {
    final origin = Uri.base.origin;
    if (origin.isNotEmpty &&
        origin != 'null' &&
        origin.startsWith('http') &&
        !origin.contains('workers.dev')) {
      return '$origin${AppRoutes.resetPassword}';
    }
    return 'https://miprofio.es${AppRoutes.resetPassword}';
  }

  static bool isPasswordRecoveryCallback(Uri uri) {
    return allParameters(uri)['type'] == 'recovery';
  }
}
