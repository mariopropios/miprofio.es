import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/profession_catalog.dart';
import '../../../../core/models/search_suggestion.dart';
import '../../../../core/services/geo_service.dart';
import '../../../../core/utils/geo_distance.dart';
import '../../../../core/utils/proximity_filter.dart';
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
    int limit = AppConstants.companiesPerPage,
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
      // Columna no existe → esquema legacy sin nuevas columnas
      if (e.code == '42703' || e.code == 'PGRST204') {
        return _fetchLegacyProfessionals(
          profession: profession,
          city: city,
          query: query,
          expandedProfessions: expandedProfessions,
          limit: limit,
        );
      }
      rethrow;
    } catch (_) {
      // Cualquier otro error (red, URL malformada, CORS…) → fallback sin filtros
      // avanzados para que la app siempre muestre algo.
      return _fetchLegacyProfessionals(
        profession: profession,
        city: city,
        query: query,
        expandedProfessions: expandedProfessions,
        limit: limit,
      );
    }
  }

  Future<Professional?> getProfessionalById(String id) async {
    try {
      final data =
          await _client.from('professionals').select().eq('id', id).maybeSingle();
      if (data == null) return null;
      return _parseProfessional(Map<String, dynamic>.from(data));
    } on PostgrestException catch (e) {
      if (e.code == '42703') {
        final data = await _client
            .from('professionals')
            .select(
              'id, name, category, description, image_url, city, rating, review_count, address, phone, email, website',
            )
            .eq('id', id)
            .maybeSingle();
        if (data == null) return null;
        return _parseProfessional(Map<String, dynamic>.from(data));
      }
      rethrow;
    }
  }

  Future<Professional> _parseProfessional(Map<String, dynamic> data) async {
    final email = data['email'] as String?;
    if (email == null || email.trim().isEmpty) {
      final ownerId = (data['owner_id'] ?? data['id'])?.toString();
      if (ownerId != null && ownerId.isNotEmpty) {
        final profile = await _client
            .from('profiles')
            .select('email')
            .eq('id', ownerId)
            .maybeSingle();
        final profileEmail = profile?['email'] as String?;
        if (profileEmail != null && profileEmail.trim().isNotEmpty) {
          data['email'] = profileEmail.trim();
        }
      }
    }
    return Professional.fromJson(data);
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
      return _parseProfessional(Map<String, dynamic>.from(data));
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
    required String address,
    required double latitude,
    required double longitude,
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
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
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
    double? latitude,
    double? longitude,
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
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
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
          ..remove('service_radius_km')
          ..remove('latitude')
          ..remove('longitude');
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
    final hasCityFilter = city != null && city.trim().isNotEmpty;
    final fetchLimit = hasCityFilter ? limit * 10 : limit * 3;

    var builder = _client.from('professionals').select();

    if (profession != null && profession.isNotEmpty) {
      builder = builder.ilike('profession', '%$profession%');
    }

    // La cercanía se resuelve por distancia (lat/lng + service_radius_km),
    // no por coincidencia de texto en el campo city.

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

    final raw = await builder.limit(fetchLimit);
    var list = (raw as List).map((e) => Professional.fromJson(e)).toList();

    // Filtro de categoría en Dart: incluye al profesional si:
    //   · Su lista de categorías contiene el categoryId solicitado, O
    //   · Su lista de categorías está vacía (profesional legacy sin categorías asignadas).
    if (categoryId != null && categoryId.isNotEmpty) {
      list = list
          .where((p) =>
              p.serviceCategories.isEmpty ||
              p.serviceCategories.contains(categoryId))
          .toList();
    }

    if (hasCityFilter) {
      list = await _filterByProximity(list, city.trim(), limit);
    } else {
      _sortByBayesian(list);
      list = list.take(limit).toList();
    }

    return list;
  }

  /// Filtra por distancia real y ordena: más cercanos primero, luego ranking.
  Future<List<Professional>> _filterByProximity(
    List<Professional> list,
    String searchCity,
    int limit,
  ) async {
    try {
      final geocoded = await GeoService.geocodeCity(searchCity);
      final searchLat = geocoded.latitude;
      final searchLng = geocoded.longitude;

      final filtered = list
          .where(
            (p) => ProximityFilter.matches(
              professional: p,
              searchLat: searchLat,
              searchLng: searchLng,
              searchCityLabel: searchCity,
            ),
          )
          .toList();

      filtered.sort(
        (a, b) => ProximityFilter.compareByDistanceThenRanking(
          a: a,
          b: b,
          searchLat: searchLat,
          searchLng: searchLng,
          rankingScore: _rankingScore,
        ),
      );

      return filtered.take(limit).toList();
    } catch (_) {
      // Si falla la geocodificación, fallback al filtro por nombre de localidad.
      final fallback = list
          .where((p) => citiesMatch(p.city, searchCity))
          .toList();
      _sortByBayesian(fallback);
      return fallback.take(limit).toList();
    }
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
      final cityFilter = city.contains(', ')
          ? city.split(', ').first.trim()
          : city.trim();
      builder = builder.ilike('city', '%$cityFilter%');
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

  /// Sugerencias de autocompletado: oficios del catálogo + empresas publicadas.
  Future<List<SearchSuggestion>> searchSuggestions(
    String query, {
    int maxProfessions = 15,
    int maxCompanies = 12,
  }) async {
    final term = query.trim();
    if (term.length < 2) return [];

    final results = <SearchSuggestion>[];
    final seen = <String>{};

    for (final match
        in ProfessionCatalog.scoredProfessionMatches(term, limit: maxProfessions)) {
      final key = 'prof:${match.item.name.toLowerCase()}';
      if (!seen.add(key)) continue;
      results.add(SearchSuggestion(
        label: match.item.name,
        kind: SearchSuggestionKind.profession,
        subtitle: 'Oficio',
        categoryId: match.item.categoryId,
      ));
    }

    final companies = await _searchCompanyNameSuggestions(
      term,
      limit: maxCompanies * 4,
    );
    final rankedCompanies = companies
        .map(
          (c) => (
            company: c,
            score: _scoreCompanySuggestion(term, c.name, c.profession),
          ),
        )
        .where((e) => e.score > 0)
        .toList()
      ..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return a.company.name.compareTo(b.company.name);
      });

    for (final entry in rankedCompanies.take(maxCompanies)) {
      final key = 'co:${entry.company.name.toLowerCase()}';
      if (!seen.add(key)) continue;
      results.add(SearchSuggestion(
        label: entry.company.name,
        kind: SearchSuggestionKind.company,
        subtitle: _matchingProfessionsSubtitle(term, entry.company.profession),
      ));
    }

    return results;
  }

  int _scoreCompanySuggestion(String query, String name, String profession) {
    final q = query.toLowerCase().trim();
    final n = name.toLowerCase();
    final professions = profession
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();

    if (n == q) return 100;
    if (n.startsWith(q)) return 85;
    if (n.contains(q)) return 70;

    var best = 0;
    for (final prof in professions) {
      final words =
          prof.split(RegExp(r'[\s/()-]+')).where((w) => w.isNotEmpty);
      if (prof == q) {
        best = best > 80 ? best : 80;
      } else if (prof.startsWith(q)) {
        best = best > 75 ? best : 75;
      } else if (words.any((w) => w.startsWith(q))) {
        best = best > 68 ? best : 68;
      } else if (prof.contains(q)) {
        best = best > 60 ? best : 60;
      }
    }

    if (best > 0) return best;
    if (profession.toLowerCase().contains(q)) return 45;
    return 0;
  }

  String _matchingProfessionsSubtitle(String query, String profession) {
    final q = query.toLowerCase().trim();
    final parts = profession
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return profession;

    final matching = parts.where((part) {
      final lower = part.toLowerCase();
      final words =
          lower.split(RegExp(r'[\s/()-]+')).where((w) => w.isNotEmpty);
      return lower.contains(q) || words.any((w) => w.startsWith(q));
    }).toList();

    final visible = (matching.isNotEmpty ? matching : parts).take(3).join(', ');
    final total = matching.isNotEmpty ? matching.length : parts.length;
    if (total > 3) return '$visible…';
    return visible;
  }

  Future<List<({String name, String profession})>> _searchCompanyNameSuggestions(
    String term, {
    int limit = 5,
  }) async {
    final safe = term.replaceAll('%', '').replaceAll('_', '');
    if (safe.isEmpty) return [];

    try {
      final raw = await _client
          .from('professionals')
          .select('name, profession')
          .or('name.ilike.%$safe%,profession.ilike.%$safe%')
          .limit(limit * 2);

      final seen = <String>{};
      final results = <({String name, String profession})>[];

      for (final row in raw as List) {
        final map = row as Map<String, dynamic>;
        final name = (map['name'] as String?)?.trim() ?? '';
        if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
        final profession = (map['profession'] as String?)?.trim() ?? '';
        results.add((name: name, profession: profession));
        if (results.length >= limit) break;
      }

      return results;
    } on PostgrestException catch (e) {
      if (e.code == '42703') {
        return _searchLegacyCompanyNameSuggestions(safe, limit: limit);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<({String name, String profession})>> _searchLegacyCompanyNameSuggestions(
    String term, {
    int limit = 5,
  }) async {
    try {
      final raw = await _client
          .from('professionals')
          .select('name, category')
          .or('name.ilike.%$term%,category.ilike.%$term%')
          .limit(limit * 2);

      final seen = <String>{};
      final results = <({String name, String profession})>[];

      for (final row in raw as List) {
        final map = row as Map<String, dynamic>;
        final name = (map['name'] as String?)?.trim() ?? '';
        if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
        final profession = (map['category'] as String?)?.trim() ?? '';
        results.add((name: name, profession: profession));
        if (results.length >= limit) break;
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  /// Puntuación de ranking combinada (0–1):
  ///
  /// 70 % — Media bayesiana del rating (C=5, m=4.0):
  ///          premia calidad y penaliza perfiles con muy pocas reseñas.
  /// 15 % — Actividad de reseñas: más reseñas = más confianza (cap 100).
  /// 15 % — Popularidad por guardados (cap 500 saves).
  ///
  /// Con esto, un profesional con 4.8★ / 20 reseñas / 50 guardados
  /// supera a uno con 5.0★ / 1 reseña / 0 guardados.
  static double _rankingScore(Professional p) {
    // 1. Bayesian rating normalizado a 0-1
    const c = 5.0;
    const m = 4.0;
    final n = p.reviewCount.toDouble();
    final avg = p.rating;
    final bayesian = (c * m + n * avg) / (c + n) / 5.0;

    // 2. Volumen de reseñas (cap en 100 para no penalizar infinitamente a nuevos)
    final reviewBonus = (p.reviewCount.clamp(0, 100)) / 100.0;

    // 3. Popularidad por guardados (cap en 500)
    final saveBonus = (p.savedCount.clamp(0, 500)) / 500.0;

    return bayesian * 0.70 + reviewBonus * 0.15 + saveBonus * 0.15;
  }

  static void _sortByBayesian(List<Professional> list) {
    list.sort((a, b) => _rankingScore(b).compareTo(_rankingScore(a)));
  }
}
