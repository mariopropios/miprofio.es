// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Borrador del registro profesional pendiente de confirmar email (web).
class PendingProfessionalDraft {
  const PendingProfessionalDraft({
    required this.userId,
    required this.email,
    required this.businessName,
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.phoneE164,
    required this.phoneDisplay,
    required this.bio,
    required this.professions,
    required this.categories,
    required this.serviceRadiusKm,
    this.avatarBytes,
    this.avatarMime = 'image/jpeg',
    this.galleryBytes = const [],
    this.galleryMimes = const [],
  });

  final String userId;
  final String email;
  final String businessName;
  final String city;
  final String address;
  final double latitude;
  final double longitude;
  final String phoneE164;
  final String phoneDisplay;
  final String bio;
  final List<String> professions;
  final List<String> categories;
  final int serviceRadiusKm;
  final Uint8List? avatarBytes;
  final String avatarMime;
  final List<Uint8List> galleryBytes;
  final List<String> galleryMimes;

  static const _storageKey = 'profio_pending_professional_draft_v1';

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'businessName': businessName,
        'city': city,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'phoneE164': phoneE164,
        'phoneDisplay': phoneDisplay,
        'bio': bio,
        'professions': professions,
        'categories': categories,
        'serviceRadiusKm': serviceRadiusKm,
        if (avatarBytes != null) 'avatarBase64': base64Encode(avatarBytes!),
        'avatarMime': avatarMime,
        'galleryBase64': galleryBytes.map(base64Encode).toList(),
        'galleryMimes': galleryMimes,
      };

  static PendingProfessionalDraft? fromJson(Map<String, dynamic> json) {
    try {
      final galleryB64 = (json['galleryBase64'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      final galleryMimes = (json['galleryMimes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          List.filled(galleryB64.length, 'image/jpeg');
      final avatarB64 = json['avatarBase64'] as String?;
      return PendingProfessionalDraft(
        userId: json['userId'] as String,
        email: json['email'] as String? ?? '',
        businessName: json['businessName'] as String? ?? '',
        city: json['city'] as String? ?? '',
        address: json['address'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        phoneE164: json['phoneE164'] as String? ?? '',
        phoneDisplay: json['phoneDisplay'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        professions: (json['professions'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        categories: (json['categories'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        serviceRadiusKm: (json['serviceRadiusKm'] as num?)?.toInt() ?? 25,
        avatarBytes:
            avatarB64 != null && avatarB64.isNotEmpty ? base64Decode(avatarB64) : null,
        avatarMime: json['avatarMime'] as String? ?? 'image/jpeg',
        galleryBytes: galleryB64.map(base64Decode).toList(),
        galleryMimes: galleryMimes.length == galleryB64.length
            ? galleryMimes
            : List.filled(galleryB64.length, 'image/jpeg'),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(PendingProfessionalDraft draft) async {
    try {
      html.window.localStorage[_storageKey] = jsonEncode(draft.toJson());
    } catch (_) {
      // Quota / private mode: guardar sin fotos.
      try {
        final light = PendingProfessionalDraft(
          userId: draft.userId,
          email: draft.email,
          businessName: draft.businessName,
          city: draft.city,
          address: draft.address,
          latitude: draft.latitude,
          longitude: draft.longitude,
          phoneE164: draft.phoneE164,
          phoneDisplay: draft.phoneDisplay,
          bio: draft.bio,
          professions: draft.professions,
          categories: draft.categories,
          serviceRadiusKm: draft.serviceRadiusKm,
        );
        html.window.localStorage[_storageKey] = jsonEncode(light.toJson());
      } catch (_) {}
    }
  }

  static PendingProfessionalDraft? load() {
    try {
      final raw = html.window.localStorage[_storageKey];
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        if (decoded is Map) {
          return fromJson(Map<String, dynamic>.from(decoded));
        }
        return null;
      }
      return fromJson(decoded);
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
