import 'package:supabase_flutter/supabase_flutter.dart';

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
    );
  }

  /// Registro con fallback a login si el email ya existe (común en pruebas).
  Future<({String userId, bool needsEmailConfirmation})> registerOrSignIn({
    required String email,
    required String password,
    required String fullName,
    String role = 'professional',
  }) async {
    final signUpResponse = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role},
    );

    final user = signUpResponse.user;
    if (user == null) {
      throw const AuthException('No se pudo crear la cuenta.');
    }

    if (signUpResponse.session != null) {
      return (userId: user.id, needsEmailConfirmation: false);
    }

    final identities = user.identities;
    if (identities != null && identities.isEmpty) {
      try {
        await signIn(email: email, password: password);
      } on AuthException catch (e) {
        throw AuthException(
          'Este email ya está registrado. Usa la contraseña correcta o inicia sesión.',
          statusCode: e.statusCode,
          code: e.code,
        );
      }

      final signedIn = currentUser;
      if (signedIn == null) {
        throw const AuthException(
          'No se pudo iniciar sesión con ese email.',
        );
      }
      return (userId: signedIn.id, needsEmailConfirmation: false);
    }

    return (userId: user.id, needsEmailConfirmation: true);
  }

  Future<void> signOut() => _client.auth.signOut();
}
