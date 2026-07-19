import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_callback_service.dart';
import 'auth_register_result.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String role = 'client',
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role},
      emailRedirectTo: kIsWeb ? AuthCallbackService.webEmailRedirectTo() : null,
    );
  }

  /// Registro con detección de email ya existente (una sola cuenta por email).
  Future<AuthRegisterResult> registerOrSignIn({
    required String email,
    required String password,
    required String fullName,
    String role = 'professional',
  }) async {
    AuthResponse signUpResponse;
    try {
      signUpResponse = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role},
        emailRedirectTo: kIsWeb ? AuthCallbackService.webEmailRedirectTo() : null,
      );
    } on AuthException catch (e) {
      if (_isAlreadyRegisteredError(e)) {
        return _existingAccountResult();
      }
      rethrow;
    }

    final user = signUpResponse.user;
    if (user == null) {
      throw const AuthException('No se pudo crear la cuenta.');
    }

    if (signUpResponse.session != null) {
      return (
        userId: user.id,
        needsEmailConfirmation: false,
        accountAlreadyExists: false,
      );
    }

    if (_isDuplicateSignup(user)) {
      return _existingAccountResult();
    }

    return (
      userId: user.id,
      needsEmailConfirmation: true,
      accountAlreadyExists: false,
    );
  }

  /// Envía un enlace seguro de recuperación al email (válido un tiempo limitado).
  ///
  /// La plantilla Auth usa `{{ .ConfirmationURL }}` (verify de Supabase +
  /// redirect_to). La app abre `/login/reset-password` y completa la sesión
  /// con el callback (hash/query).
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: kIsWeb ? AuthCallbackService.webPasswordResetRedirectTo() : null,
    );
  }

  /// Valida el enlace de recuperación (token_hash o code PKCE) y abre sesión.
  Future<bool> completePasswordRecoveryFromUrl(Uri uri) async {
    if (currentSession != null) return true;

    final tokenHash = AuthCallbackService.recoveryTokenHash(uri);
    if (tokenHash != null &&
        AuthCallbackService.isPasswordRecoveryCallback(uri)) {
      await _client.auth.verifyOTP(
        type: OtpType.recovery,
        tokenHash: tokenHash,
      );
      return currentSession != null;
    }

    if (AuthCallbackService.isAuthCallback(uri)) {
      await _client.auth.getSessionFromUrl(uri);
      return currentSession != null;
    }

    return false;
  }

  /// Establece una nueva contraseña tras abrir el enlace de recuperación.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  AuthRegisterResult _existingAccountResult() {
    return (
      userId: null,
      needsEmailConfirmation: false,
      accountAlreadyExists: true,
    );
  }

  bool _isDuplicateSignup(User user) {
    final identities = user.identities;
    return identities == null || identities.isEmpty;
  }

  bool _isAlreadyRegisteredError(AuthException e) {
    final code = e.code?.toLowerCase() ?? '';
    final message = e.message.toLowerCase();
    return code.contains('already') ||
        code == 'user_already_exists' ||
        message.contains('already registered') ||
        message.contains('already exists') ||
        message.contains('user already registered');
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Soft-delete de ficha (si hay) + borrado del usuario Auth vía Edge Function.
  Future<void> deleteMyAccount() async {
    final response = await _client.functions.invoke('delete-account');
    final data = response.data;

    if (response.status != 200) {
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'No se pudo eliminar la cuenta.';
      throw AuthException(message);
    }

    // La sesión local puede quedar inválida tras borrar el usuario.
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }

  /// Reenvía el email de confirmación al usuario actual o al email indicado.
  Future<void> resendVerificationEmail(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: kIsWeb ? AuthCallbackService.webEmailRedirectTo() : null,
      );
    } on AuthException catch (e) {
      throw AuthException(mapVerificationEmailError(e));
    }
  }

  /// Corrige el email de una cuenta aún no confirmada (evita registros huérfanos).
  Future<void> correctUnconfirmedEmail({
    required String userId,
    required String oldEmail,
    required String newEmail,
  }) async {
    final response = await _client.functions.invoke(
      'correct-signup-email',
      body: {
        'userId': userId,
        'oldEmail': oldEmail.trim(),
        'newEmail': newEmail.trim(),
      },
    );

    final data = response.data;
    if (response.status != 200) {
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'No se pudo actualizar el email.';
      throw AuthException(message);
    }
  }

  static String mapVerificationEmailError(AuthException e) {
    final code = e.code?.toLowerCase() ?? '';
    final message = e.message.toLowerCase();

    if (code.contains('invalid') ||
        message.contains('invalid') ||
        message.contains('unable to validate') ||
        message.contains('is not a valid')) {
      return 'El email no parece válido. Revísalo y corrígelo antes de reenviar.';
    }

    if (message.contains('rate') || message.contains('too many')) {
      return 'Demasiados intentos. Espera un momento y vuelve a probar.';
    }

    if (message.contains('not found') || message.contains('user not found')) {
      return 'No hay ninguna cuenta pendiente con ese email. Regístrate de nuevo.';
    }

    return 'No se pudo enviar el email. Comprueba que la dirección esté bien escrita.';
  }
}
