import '../router/routes.dart';
import 'post_email_confirm_path_store_stub.dart'
    if (dart.library.html) 'post_email_confirm_path_store_web.dart'
    as path_store;

/// Destino tras confirmar el email (sale de `/auth/confirm`).
class PostEmailConfirmRedirect {
  PostEmailConfirmRedirect._();

  static String? _sessionPath;

  static String? safeInternalPath(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var path = raw.trim();
    try {
      path = Uri.decodeComponent(path);
    } catch (_) {}
    if (!path.startsWith('/')) return null;
    if (path.startsWith('//')) return null;
    if (path.contains('://')) return null;
    return path;
  }

  static String defaultPath() => AppRoutes.profileAfterEmailVerification();

  /// Destino tras registro pendiente de confirmar email.
  static String pathForRole(String role, {String? redirectTo}) {
    if (role == 'professional') {
      return Uri(
        path: AppRoutes.professionalRegister,
        queryParameters: {'resume': '1'},
      ).toString();
    }
    final safeRedirect = safeInternalPath(redirectTo);
    if (safeRedirect != null &&
        safeRedirect != AppRoutes.home &&
        !safeRedirect.startsWith(AppRoutes.login) &&
        !safeRedirect.startsWith(AppRoutes.register) &&
        !safeRedirect.startsWith(AppRoutes.emailVerification) &&
        !safeRedirect.startsWith(AppRoutes.authConfirm)) {
      return safeRedirect;
    }
    return defaultPath();
  }

  static Future<void> save(String path) async {
    final safe = safeInternalPath(path) ?? defaultPath();
    _sessionPath = safe;
    await path_store.persistPath(safe);
  }

  static Future<void> clearSaved() async {
    _sessionPath = null;
    await path_store.clearPersistedPath();
  }

  /// Prioridad: `next` en URL → memoria → localStorage → perfil.
  static Future<String> resolve({String? nextFromUrl}) async {
    final fromUrl = safeInternalPath(nextFromUrl);
    if (fromUrl != null) {
      await clearSaved();
      return _withVerifiedBanner(fromUrl);
    }
    final saved =
        _sessionPath ?? safeInternalPath(await path_store.loadPersistedPath());
    _sessionPath = null;
    await path_store.clearPersistedPath();
    if (saved != null) return _withVerifiedBanner(saved);
    return defaultPath();
  }

  static String _withVerifiedBanner(String path) {
    final uri = Uri.parse(path);
    if (uri.path == AppRoutes.profile &&
        !AppRoutes.isProfileEmailVerified(uri)) {
      return AppRoutes.profileAfterEmailVerification();
    }
    return path;
  }
}
