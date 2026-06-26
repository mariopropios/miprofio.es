import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Servicio de geolocalización multiplataforma (web, Android, iOS).
class GeoService {
  /// Obtiene el nombre de la ciudad actual del dispositivo.
  /// Lanza [GeoServiceException] si no se puede obtener.
  static Future<String> detectCity() async {
    // 1. Pedir/verificar permisos
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const GeoServiceException(
          'Los servicios de ubicación están desactivados.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const GeoServiceException('Permiso de ubicación denegado.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const GeoServiceException(
          'Permiso de ubicación denegado permanentemente. '
          'Actívalo desde los ajustes del dispositivo.');
    }

    // 2. Obtener posición con timeout forzado desde fuera
    // (en web el timeLimit interno no siempre funciona)
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 8),
      ),
    ).timeout(
      const Duration(seconds: 12),
      onTimeout: () => throw const GeoServiceException(
        'La detección tardó demasiado. Escribe la ciudad manualmente.',
      ),
    );

    // 3. Geocodificación inversa con Nominatim
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=${pos.latitude}&lon=${pos.longitude}'
      '&format=json&accept-language=es',
    );

    final resp = await http.get(
      uri,
      headers: {'User-Agent': 'ProfioApp/1.0'},
    ).timeout(const Duration(seconds: 8));

    if (resp.statusCode != 200) {
      throw const GeoServiceException('Error al obtener la ciudad (Nominatim).');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final addr = data['address'] as Map<String, dynamic>? ?? {};
    final city = (addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['municipality'] ??
            addr['county'] ??
            '') as String;

    if (city.isEmpty) {
      throw const GeoServiceException('No se pudo identificar la ciudad.');
    }

    return city;
  }

  /// Busca municipios/ciudades que coincidan con [query] (mín. 2 caracteres).
  /// Devuelve hasta [limit] sugerencias con nombre corto y nombre con provincia.
  static Future<List<CitySuggestion>> searchCities(
    String query, {
    int limit = 6,
    String countryCode = 'es',
  }) async {
    if (query.trim().length < 2) return [];

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(query.trim())}'
      '&format=json'
      '&addressdetails=1'
      '&countrycodes=$countryCode'
      '&limit=$limit'
      '&accept-language=es',
    );

    try {
      final resp = await http
          .get(uri, headers: {'User-Agent': 'ProfioApp/1.0'})
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as List<dynamic>;

      final seen = <String>{};
      final results = <CitySuggestion>[];

      for (final item in data) {
        final addr =
            (item['address'] as Map<String, dynamic>?) ?? {};
        final city = (addr['city'] ??
                addr['town'] ??
                addr['village'] ??
                addr['hamlet'] ??
                addr['municipality'] ??
                '') as String;
        if (city.isEmpty) continue;

        final province = (addr['province'] ??
                addr['state'] ??
                '') as String;

        final shortName = city;
        final displayName =
            province.isNotEmpty && province != city
                ? '$city, $province'
                : city;

        if (seen.add(shortName.toLowerCase())) {
          results.add(CitySuggestion(
            shortName: shortName,
            displayName: displayName,
          ));
        }
      }

      return results;
    } catch (_) {
      return [];
    }
  }
}

class CitySuggestion {
  const CitySuggestion({
    required this.shortName,
    required this.displayName,
  });

  /// Lo que se escribe en el campo (solo la ciudad).
  final String shortName;

  /// Lo que se muestra en el desplegable (ciudad + provincia).
  final String displayName;
}

class GeoServiceException implements Exception {
  const GeoServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
