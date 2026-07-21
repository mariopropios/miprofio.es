import 'dart:typed_data';

/// Stub: borrador cliente solo en web (localStorage).
class PendingClientDraft {
  const PendingClientDraft({
    required this.userId,
    required this.email,
    required this.fullName,
    this.avatarBytes,
    this.avatarMime = 'image/jpeg',
    this.redirectTo,
  });

  final String userId;
  final String email;
  final String fullName;
  final Uint8List? avatarBytes;
  final String avatarMime;
  final String? redirectTo;

  static Future<void> save(PendingClientDraft draft) async {}

  static PendingClientDraft? load() => null;

  static Future<void> clear() async {}
}
