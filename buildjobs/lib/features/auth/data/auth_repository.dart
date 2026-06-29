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

  /// Registro con detección de email ya existente.
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
        return _resolveExistingAccount(email: email, password: password);
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
      return _resolveExistingAccount(email: email, password: password);
    }

    return (
      userId: user.id,
      needsEmailConfirmation: true,
      accountAlreadyExists: false,
    );
  }

  Future<AuthRegisterResult> _resolveExistingAccount({
    required String email,
    required String password,
  }) async {
    try {
      await signIn(email: email, password: password);
    } on AuthException catch (e) {
      if (_isEmailNotConfirmedError(e)) {
        return (
          userId: null,
          needsEmailConfirmation: true,
          accountAlreadyExists: false,
        );
      }
      return (
        userId: null,
        needsEmailConfirmation: false,
        accountAlreadyExists: true,
      );
    }

    final signedIn = currentUser;
    if (signedIn == null) {
      return (
        userId: null,
        needsEmailConfirmation: false,
        accountAlreadyExists: true,
      );
    }

    if (currentSession == null) {
      return (
        userId: signedIn.id,
        needsEmailConfirmation: true,
        accountAlreadyExists: false,
      );
    }

    return (
      userId: signedIn.id,
      needsEmailConfirmation: false,
      accountAlreadyExists: false,
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

  bool _isEmailNotConfirmedError(AuthException e) {
    final code = e.code?.toLowerCase() ?? '';
    final message = e.message.toLowerCase();
    return code.contains('email_not_confirmed') ||
        message.contains('email not confirmed') ||
        message.contains('confirm your email');
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
