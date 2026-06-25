import '../../core/utils/profession_labels.dart';

class Professional {
  const Professional({
    required this.id,
    required this.name,
    required this.profession,
    required this.city,
    required this.rating,
    required this.reviewCount,
    this.description,
    this.profilePhoto,
    this.galleryPhotos = const [],
    this.address,
    this.phone,
    this.website,
    this.serviceRadiusKm = 25,
    this.serviceCategories = const [],
  });

  final String id;
  final String name;
  final String profession;
  final String city;
  final double rating;
  final int reviewCount;
  final String? description;
  final String? profilePhoto;
  final List<String> galleryPhotos;
  final String? address;
  final String? phone;
  final String? website;
  /// Radio máximo de desplazamiento (km). Por defecto 25 km.
  final int serviceRadiusKm;
  /// Categorías del catálogo en las que el profesional quiere aparecer.
  final List<String> serviceCategories;

  /// Compatibilidad con código que usaba `category` e `imageUrl`.
  String get category => profession;
  String? get imageUrl => profilePhoto;

  /// Oficios individuales (soporta varios separados por coma).
  List<String> get professions => ProfessionLabels.parse(profession);

  String get primaryProfession =>
      professions.isNotEmpty ? professions.first : profession;

  /// Fotos para mostrar en galería (sin duplicar la de portada).
  List<String> get workGalleryPhotos {
    if (galleryPhotos.isNotEmpty) return galleryPhotos;
    if (profilePhoto != null && profilePhoto!.isNotEmpty) {
      return [profilePhoto!];
    }
    return const [];
  }

  factory Professional.fromJson(Map<String, dynamic> json) {
    return Professional(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      profession: (json['profession'] ?? json['category'] ?? 'Sin especificar')
          as String,
      city: json['city'] as String? ?? '',
      rating: _toDouble(json['rating']),
      reviewCount: _toInt(json['review_count']),
      description: json['description'] as String?,
      profilePhoto: (json['profile_photo'] ?? json['image_url']) as String?,
      galleryPhotos: _parseGalleryPhotos(json['gallery_photos']),
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      serviceRadiusKm: _toInt(json['service_radius_km']) > 0
          ? _toInt(json['service_radius_km'])
          : 25,
      serviceCategories: _parseStringList(json['service_categories']),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((u) => u.isNotEmpty).toList();
    }
    return const [];
  }

  static List<String> _parseGalleryPhotos(dynamic value) =>
      _parseStringList(value);

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'profession': profession,
        'city': city,
        'rating': rating,
        'review_count': reviewCount,
        'description': description,
        'profile_photo': profilePhoto,
        'gallery_photos': galleryPhotos,
        'address': address,
        'phone': phone,
        'website': website,
        'service_radius_km': serviceRadiusKm,
        'service_categories': serviceCategories,
      };
}
