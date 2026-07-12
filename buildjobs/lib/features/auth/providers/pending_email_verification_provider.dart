import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Datos del registro pendiente de confirmar por email (solo en memoria).
class PendingEmailVerification {
  const PendingEmailVerification({
    required this.userId,
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
  });

  final String userId;
  final String email;
  final String password;
  final String fullName;
  final String role;

  PendingEmailVerification copyWith({String? email}) {
    return PendingEmailVerification(
      userId: userId,
      email: email ?? this.email,
      password: password,
      fullName: fullName,
      role: role,
    );
  }
}

class PendingEmailVerificationNotifier
    extends Notifier<PendingEmailVerification?> {
  @override
  PendingEmailVerification? build() => null;

  void set(PendingEmailVerification data) => state = data;

  void updateEmail(String email) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(email: email.trim());
  }

  void clear() => state = null;
}

final pendingEmailVerificationProvider =
    NotifierProvider<PendingEmailVerificationNotifier,
        PendingEmailVerification?>(
  PendingEmailVerificationNotifier.new,
);
