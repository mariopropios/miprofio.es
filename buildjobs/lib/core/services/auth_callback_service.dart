import '../router/routes.dart';

/// Detecta URLs de retorno de Supabase (confirmación de email, OAuth, etc.).
class AuthCallbackService {
  AuthCallbackService._();

  static bool isAuthCallback(Uri uri) {
    final query = uri.queryParameters;
    if (query.containsKey('code')) return true;
    if (query.containsKey('error') || query.containsKey('error_description')) {
      return true;
    }
    if (query.containsKey('access_token') || query.containsKey('refresh_token')) {
      return true;
    }

    final fragment = uri.fragment;
    if (fragment.isEmpty) return false;
    return fragment.contains('access_token') ||
        fragment.contains('refresh_token') ||
        fragment.contains('code=');
  }

  /// Destino tras confirmar email en web (debe estar en Redirect URLs de Supabase).
  static String webEmailRedirectTo() {
    return '${Uri.base.origin}${AppRoutes.profileAfterEmailVerification()}';
  }
}
