import 'dart:math' as math;

/// Distancias geográficas en kilómetros (Haversine).
abstract final class GeoDistance {
  static const earthRadiusKm = 6371.0;

  /// Distancia en línea recta sobre la esfera entre dos puntos WGS84.
  static double haversineKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;
}

/// Normaliza "Ciudad, Provincia" → "ciudad".
String normalizeCityName(String city) {
  final trimmed = city.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.contains(', ')) {
    return trimmed.split(', ').first.trim().toLowerCase();
  }
  return trimmed.toLowerCase();
}

/// Compara localidades ignorando provincia y mayúsculas.
bool citiesMatch(String a, String b) {
  final left = normalizeCityName(a);
  final right = normalizeCityName(b);
  if (left.isEmpty || right.isEmpty) return false;
  return left == right;
}
