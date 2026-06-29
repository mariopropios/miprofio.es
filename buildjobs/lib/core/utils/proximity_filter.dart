import '../../shared/models/professional.dart';
import 'geo_distance.dart';

/// Filtra profesionales según el radio de desplazamiento del profesional.
abstract final class ProximityFilter {
  /// A partir de 150 km el slider significa "me desplazo mucho" → sin tope práctico.
  static const unlimitedRadiusKm = 9999.0;

  static double effectiveRadiusKm(int serviceRadiusKm) {
    if (serviceRadiusKm >= 150) return unlimitedRadiusKm;
    if (serviceRadiusKm <= 0) return 25;
    return serviceRadiusKm.toDouble();
  }

  static double? distanceKm(
    Professional professional, {
    required double searchLat,
    required double searchLng,
  }) {
    final lat = professional.latitude;
    final lng = professional.longitude;
    if (lat == null || lng == null) return null;
    return GeoDistance.haversineKm(
      lat1: lat,
      lon1: lng,
      lat2: searchLat,
      lon2: searchLng,
    );
  }

  /// `true` si el profesional cubre la localidad buscada.
  static bool matches({
    required Professional professional,
    required double searchLat,
    required double searchLng,
    required String searchCityLabel,
  }) {
    final distance = distanceKm(
      professional,
      searchLat: searchLat,
      searchLng: searchLng,
    );

    if (distance != null) {
      return distance <= effectiveRadiusKm(professional.serviceRadiusKm);
    }

    // Sin coordenadas: fallback por nombre de localidad (perfiles legacy).
    return citiesMatch(professional.city, searchCityLabel);
  }

  static int compareByDistanceThenRanking({
    required Professional a,
    required Professional b,
    required double searchLat,
    required double searchLng,
    required double Function(Professional) rankingScore,
  }) {
    final da = distanceKm(a, searchLat: searchLat, searchLng: searchLng);
    final db = distanceKm(b, searchLat: searchLat, searchLng: searchLng);

    if (da != null && db != null) {
      final byDistance = da.compareTo(db);
      if (byDistance != 0) return byDistance;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }

    return rankingScore(b).compareTo(rankingScore(a));
  }
}
