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
  /// Requiere plantilla de email en Supabase con enlace directo:
  /// `{{ .RedirectTo }}?token_hash={{ .TokenHash }}&type=recovery`
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

  /// Reenvía el email de confirmación al usuario actual o al email indicado.
  Future<void> resendVerificationEmail(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: kIsWeb ? AuthCallbackService.webEmailRedirectTo() : null,
    );
  }
}
