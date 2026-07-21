import 'dart:typed_data';

/// Stub: el borrador profesional solo se persiste en web (localStorage).
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

  static Future<void> save(PendingProfessionalDraft draft) async {}

  static PendingProfessionalDraft? load() => null;

  static Future<void> clear() async {}
}
