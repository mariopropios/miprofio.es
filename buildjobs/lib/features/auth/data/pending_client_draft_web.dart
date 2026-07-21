// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Borrador del registro cliente pendiente de confirmar email (web).
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

  static const _storageKey = 'profio_pending_client_draft_v1';

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'fullName': fullName,
        if (avatarBytes != null) 'avatarBase64': base64Encode(avatarBytes!),
        'avatarMime': avatarMime,
        if (redirectTo != null) 'redirectTo': redirectTo,
      };

  static PendingClientDraft? fromJson(Map<String, dynamic> json) {
    try {
      final avatarB64 = json['avatarBase64'] as String?;
      return PendingClientDraft(
        userId: json['userId'] as String,
        email: json['email'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        avatarBytes: avatarB64 != null && avatarB64.isNotEmpty
            ? base64Decode(avatarB64)
            : null,
        avatarMime: json['avatarMime'] as String? ?? 'image/jpeg',
        redirectTo: json['redirectTo'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(PendingClientDraft draft) async {
    try {
      html.window.localStorage[_storageKey] = jsonEncode(draft.toJson());
    } catch (_) {
      try {
        final light = PendingClientDraft(
          userId: draft.userId,
          email: draft.email,
          fullName: draft.fullName,
          redirectTo: draft.redirectTo,
        );
        html.window.localStorage[_storageKey] = jsonEncode(light.toJson());
      } catch (_) {}
    }
  }

  static PendingClientDraft? load() {
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return fromJson(decoded);
      if (decoded is Map) {
        return fromJson(Map<String, dynamic>.from(decoded));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      html.window.localStorage.remove(_storageKey);
    } catch (_) {}
  }
}
