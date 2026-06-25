import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/models/professional.dart';

class ProfessionalRepository {
  ProfessionalRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Professional>> getProfessionals({
    String? profession,
    String? categoryId,
    String? city,
    String? query,
    List<String> expandedProfessions = const [],
    int limit = 20,
  }) async {
    try {
      return await _fetchProfessionals(
        profession: profession,
        categoryId: categoryId,
        city: city,
        query: query,
        expandedProfessions: expandedProfessions,
        limit: limit,
      );
    } on PostgrestException catch (e) {
      if (e.code == '42703') {
        return _fetchLegacyProfessionals(
          profession: profession,
          city: city,
          query: query,
          expandedProfessions: expandedProfessions,
          limit: limit,
        );
      }
      rethrow;
    }
  }

  Future<Professional?> getProfessionalById(String id) async {
    try {
      final data =
          await _client.from('professionals').select().eq('id', id).maybeSingle();
      if (data == null) return null;
      return Professional.fromJson(data);
    } on PostgrestException catch (e) {
      if (e.code == '42703') {
        final data = await _client
            .from('professionals')
            .select(
              'id, name, category, description, image_url, city, rating, review_count, address, phone, website',
            )
            .eq('id', id)
            .maybeSingle();
        if (data == null) return null;
        return Professional.fromJson(data);
      }
      rethrow;
    }
  }

  /// Busca la ficha del usuario: por id (= userId) o por owner_id (esquema legacy).
  Future<Professional?> getProfessionalForUser(String userId) async {
    final byId = await getProfessionalById(userId);
    if (byId != null) return byId;

    try {
      final data = await _client
          .from('professionals')
          .select()
          .eq('owner_id', userId)
          .maybeSingle();
      if (data == null) return null;
      return Professional.fromJson(data);
    } on PostgrestException catch (e) {
      if (e.code == '42703') return null;
      rethrow;
    }
  }

  Future<void> updateGalleryPhotos({
    required String userId,
    required List<String> galleryPhotoUrls,
  }) async {
    final profilePhotoUrl =
        galleryPhotoUrls.isNotEmpty ? galleryPhotoUrls.first : null;

    final payload = <String, dynamic>{
      'gallery_photos': galleryPhotoUrls,
      if (profilePhotoUrl != null) 'profile_photo': profilePhotoUrl,
    };

    try {
      await _client.from('professionals').update(payload).eq('id', userId);
    } on PostgrestException catch (e) {
      if (e.code == '42703') {
        if (profilePhotoUrl != null) {
          await _client
              .from('professionals')
              .update({'profile_photo': profilePhotoUrl})
              .eq('id', userId);
        }
        return;
      }
      rethrow;
    }
  }

  Future<void> createProfessional({
    required String name,
    required List<String> professions,
    required String description,
    required String city,
    String? phone,
    String? email,
    String? profilePhotoUrl,
    List<String> galleryPhotoUrls = const [],
    required String userId,
    int serviceRadiusKm = 25,
    List<String> serviceCategories = const [],
  }) async {
    final professionLabel = professions.join(', ');

    final payload = <String, dynamic>{
      'id': userId,
      'name': name,
      'profession': professionLabel,
      'description': description,
      'city': city,
      'type': 'individual',
      'service_radius_km': serviceRadiusKm,
      if (serviceCategories.isNotEmpty)
        'service_categories': serviceCategories,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (profilePhotoUrl != null) 'profile_photo': profilePhotoUrl,
      if (galleryPhotoUrls.isNotEmpty) 'gallery_photos': galleryPhotoUrls,
    };

    try {
      await _client.from('professionals').upsert(
        {...payload, 'owner_id': userId},
        onConflict: 'id',
      );
    } on PostgrestException catch (e) {
      if (e.code == '42703') {
        payload.remove('gallery_photos');
        try {
          await _client.from('professionals').upsert(
            {...payload, 'owner_id': userId},
            onConflict: 'id',
          );
        } on PostgrestException catch (e2) {
          if (e2.code != '42703') rethrow;
          await _client.from('professionals').upsert(payload, onConflict: 'id');
        }
        return;
      }
      rethrow;
    }
  }

  Future<void> updateProfessional({
    required String professionalId,
    String? name,
    String? profession,
    String? city,
    String? phone,
    String? website,
    String? address,
    String? description,
    String? profilePhotoUrl,
    List<String>? galleryPhotoUrls,
    int? serviceRadiusKm,
    List<String>? serviceCategories,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (profession != null) payload['profession'] = profession;
    if (city != null) payload['city'] = city;
    if (phone != null) payload['phone'] = phone;
    if (website != null) payload['website'] = website;
    if (address != null) payload['address'] = address;
    if (description != null) payload['description'] = description;
    if (profilePhotoUrl != null) payload['profile_photo'] = profilePhotoUrl;
    if (galleryPhotoUrls != null) payload['gallery_photos'] = galleryPhotoUrls;
    if (serviceRadiusKm != null) payload['service_radius_km'] = serviceRadiusKm;
    if (serviceCategories != null) payload['service_categories'] = serviceCategories;
    if (payload.isEmpty) return;

    try {
      await _client
          .from('professionals')
          .update(payload)
          .eq('id', professionalId);
    } on PostgrestException catch (e) {
      // Columna no encontrada en la caché del esquema (migración pendiente)
      if (e.code == 'PGRST204' || e.code == '42703') {
        // Reintento sin las columnas más nuevas
        final fallback = Map<String, dynamic>.from(payload)
          ..remove('service_categories')
          ..remove('service_radius_km');
        if (fallback.isEmpty) return;
        try {
          await _client
              .from('professionals')
              .update(fallback)
              .eq('id', professionalId);
        } on PostgrestException catch (e2) {
          if (e2.code == 'PGRST204' || e2.code == '42703') {
            // Reintento sin galería también (por si la migración es muy antigua)
            final minimal = Map<String, dynamic>.from(fallback)
              ..remove('gallery_photos');
            if (minimal.isEmpty) return;
            await _client
                .from('professionals')
                .update(minimal)
                .eq('id', professionalId);
            return;
          }
          rethrow;
        }
        return;
      }
      rethrow;
    }
  }

  Future<List<Professional>> _fetchProfessionals({
    String? profession,
    String? categoryId,
    String? city,
    String? query,
    List<String> expandedProfessions = const [],
    required int limit,
  }) async {
    var builder = _client.from('professionals').select();

    if (profession != null && profession.isNotEmpty) {
      builder = builder.ilike('profession', '%$profession%');
    }

    if (city != null && city.isNotEmpty) {
      builder = builder.ilike('city', '%$city%');
    }

    // Filtrar por categoría si el profesional ha optado en ella.
    // Se ignora si service_categories está vacío (profesionales antiguos sin migrar).
    if (categoryId != null && categoryId.isNotEmpty) {
      builder = builder.or(
        'service_categories.cs.["$categoryId"],'
        'service_categories.eq.[]',
      );
    }

    if (query != null && query.trim().isNotEmpty) {
      final term = query.trim();
      // Condiciones base: nombre, ciudad, profesión y descripción del profesional
      final parts = [
        'name.ilike.%$term%',
        'city.ilike.%$term%',
        'profession.ilike.%$term%',
        'description.ilike.%$term%',
      ];
      // Condiciones derivadas de la expansión semántica por el catálogo
      for (final prof in expandedProfessions) {
        parts.add('profession.ilike.%$prof%');
      }
      builder = builder.or(parts.join(','));
    } else if (expandedProfessions.isNotEmpty && profession == null) {
      // Sólo expansión semántica sin texto libre
      final parts =
          expandedProfessions.map((p) => 'profession.ilike.%$p%').toList();
      builder = builder.or(parts.join(','));
    }

    final raw = await builder.limit(limit * 3);
    final list = (raw as List).map((e) => Professional.fromJson(e)).toList();
    _sortByBayesian(list);
    return list.take(limit).toList();
  }

  Future<List<Professional>> _fetchLegacyProfessionals({
    String? profession,
    String? city,
    String? query,
    List<String> expandedProfessions = const [],
    required int limit,
  }) async {
    var builder = _client.from('professionals').select();

    if (profession != null && profession.isNotEmpty) {
      builder = builder.ilike('category', '%$profession%');
    }

    if (city != null && city.isNotEmpty) {
      builder = builder.ilike('city', '%$city%');
    }

    if (query != null && query.trim().isNotEmpty) {
      final term = query.trim();
      final parts = [
        'name.ilike.%$term%',
        'city.ilike.%$term%',
        'category.ilike.%$term%',
        'description.ilike.%$term%',
      ];
      for (final prof in expandedProfessions) {
        parts.add('category.ilike.%$prof%');
      }
      builder = builder.or(parts.join(','));
    } else if (expandedProfessions.isNotEmpty && profession == null) {
      final parts =
          expandedProfessions.map((p) => 'category.ilike.%$p%').toList();
      builder = builder.or(parts.join(','));
    }

    final raw = await builder.limit(limit * 3);
    final list = (raw as List).map((e) => Professional.fromJson(e)).toList();
    _sortByBayesian(list);
    return list.take(limit).toList();
  }

  /// Media bayesiana: (C*m + n*avg) / (C+n)  —  C=5, m=4.0
  /// Penaliza a quien tiene pocas reseñas respecto a quien tiene muchas.
  static double _bayesian(Professional p) {
    const c = 5.0;
    const m = 4.0;
    final n = p.reviewCount.toDouble();
    final avg = p.rating;
    return (c * m + n * avg) / (c + n);
  }

  static void _sortByBayesian(List<Professional> list) {
    list.sort((a, b) => _bayesian(b).compareTo(_bayesian(a)));
  }
}
