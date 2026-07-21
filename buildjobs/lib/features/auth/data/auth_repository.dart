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
    Map<String, dynamic>? extraMetadata,
  }) async {
    AuthResponse signUpResponse;
    try {
      signUpResponse = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
          if (extraMetadata != null) ...extraMetadata,
        },
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
    return completeAuthCallbackFromUrl(uri, recoveryOnly: true);
  }

  /// Completa callbacks de Auth al abrir la app (confirmación email, recovery, PKCE).
  Future<bool> completeAuthCallbackFromUrl(
    Uri uri, {
    bool recoveryOnly = false,
  }) async {
    if (!AuthCallbackService.isAuthCallback(uri) &&
        AuthCallbackService.recoveryTokenHash(uri) == null) {
      return currentSession != null;
    }

    final tokenHash = AuthCallbackService.recoveryTokenHash(uri);
    final type = AuthCallbackService.authCallbackType(uri);

    if (tokenHash != null) {
      if (AuthCallbackService.isPasswordRecoveryCallback(uri)) {
        if (currentSession != null && recoveryOnly) return true;
        await _client.auth.verifyOTP(
          type: OtpType.recovery,
          tokenHash: tokenHash,
        );
        return currentSession != null;
      }

      if (!recoveryOnly &&
          !AuthCallbackService.isPasswordRecoveryCallback(uri)) {
        final preferred = switch (type) {
          'invite' => OtpType.invite,
          'email' => OtpType.email,
          'magiclink' => OtpType.magiclink,
          _ => OtpType.signup,
        };
        final otpTypes = <OtpType>[
          preferred,
          if (preferred != OtpType.signup) OtpType.signup,
          if (preferred != OtpType.email) OtpType.email,
        ];
        Object? lastError;
        for (final otpType in otpTypes) {
          try {
            await _client.auth.verifyOTP(
              type: otpType,
              tokenHash: tokenHash,
            );
            if (currentSession != null) return true;
          } catch (e) {
            lastError = e;
          }
        }
        if (currentSession != null) return true;
        if (lastError != null) throw lastError;
        return false;
      }

      if (recoveryOnly) return currentSession != null;
    }

    // PKCE / hash: access_token, code, etc. (tras ConfirmationURL de Supabase).
    if (AuthCallbackService.isAuthCallback(uri)) {
      try {
        await _client.auth.getSessionFromUrl(uri);
      } catch (_) {
        // detectSessionInUri pudo haberlo consumido ya en initialize.
      }
      return currentSession != null;
    }

    return currentSession != null;
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

  /// Reenvía el email de confirmación (código OTP + enlace de respaldo).
  Future<void> resendVerificationEmail(String email) => resendEmailOtp(email);

  /// Reenvía un código de confirmación al email (invalidá el anterior).
  Future<void> resendEmailOtp(String email) async {
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

  /// Confirma el alta con el código de 6 dígitos recibido por email.
  ///
  /// Usa `signup` (confirmación de registro). Si falla, reintenta con `email`.
  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final token = code.trim();
    final trimmedEmail = email.trim();
    if (token.isEmpty) {
      throw const AuthException('Introduce el código del email.');
    }

    Object? lastError;
    for (final otpType in <OtpType>[OtpType.signup, OtpType.email]) {
      try {
        await _client.auth.verifyOTP(
          type: otpType,
          email: trimmedEmail,
          token: token,
        );
        if (currentSession != null) return;
      } catch (e) {
        lastError = e;
      }
    }

    if (currentSession != null) return;

    if (lastError is AuthException) {
      throw AuthException(mapOtpVerifyError(lastError));
    }
    throw AuthException(
      lastError != null
          ? mapOtpVerifyError(
              AuthException(lastError.toString()),
            )
          : 'Código incorrecto o caducado. Pide uno nuevo e inténtalo de nuevo.',
    );
  }

  static String mapOtpVerifyError(AuthException e) {
    final code = e.code?.toLowerCase() ?? '';
    final message = e.message.toLowerCase();

    if (message.contains('expired') || code.contains('expired')) {
      return 'El código ha caducado. Pide uno nuevo.';
    }
    if (message.contains('invalid') ||
        message.contains('otp') ||
        code.contains('otp') ||
        message.contains('token')) {
      return 'Código incorrecto. Revisa el email e inténtalo de nuevo.';
    }
    if (message.contains('rate') || message.contains('too many')) {
      return 'Demasiados intentos. Espera un momento o pide un código nuevo.';
    }
    return e.message.isNotEmpty
        ? e.message
        : 'No se pudo verificar el código. Inténtalo de nuevo.';
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
