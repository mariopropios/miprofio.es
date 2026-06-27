import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Servicio de geolocalización multiplataforma (web, Android, iOS).
class GeoService {
  static const _detectTimeout = Duration(seconds: 18);

  /// Obtiene el nombre de la ciudad actual del dispositivo.
  /// Lanza [GeoServiceException] si no se puede obtener.
  static Future<String> detectCity() {
    return _detectCityImpl().timeout(
      _detectTimeout,
      onTimeout: () => throw const GeoServiceException(
        'La detección tardó demasiado. Escribe la ciudad manualmente '
        'o comprueba que el navegador tenga permiso de ubicación.',
      ),
    );
  }

  static Future<String> _detectCityImpl() async {
    await _ensureLocationPermission();

    final pos = await _resolvePosition();

    return _reverseGeocodeCity(pos.latitude, pos.longitude);
  }

  static Future<void> _ensureLocationPermission() async {
    if (!kIsWeb) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const GeoServiceException(
          'Los servicios de ubicación están desactivados.',
        );
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      try {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 25),
          onTimeout: () => LocationPermission.denied,
        );
      } catch (_) {
        permission = LocationPermission.denied;
      }
      if (permission == LocationPermission.denied) {
        throw const GeoServiceException(
          'Permiso de ubicación denegado. Actívalo en el navegador '
          'y vuelve a intentarlo.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const GeoServiceException(
        'Permiso de ubicación bloqueado. Actívalo en los ajustes '
        'del navegador o del dispositivo.',
      );
    }
  }

  static LocationSettings get _locationSettings {
    if (kIsWeb) {
      return WebSettings(
        accuracy: LocationAccuracy.low,
        maximumAge: const Duration(minutes: 10),
        timeLimit: const Duration(seconds: 10),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.low,
      timeLimit: Duration(seconds: 8),
    );
  }

  static Future<Position> _resolvePosition() async {
    // Última posición conocida: respuesta rápida si el navegador la tiene.
    try {
      final last = await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 3));
      if (last != null) return last;
    } catch (_) {
      // Continuar con GPS actual.
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw const GeoServiceException(
          'No se pudo obtener la ubicación a tiempo. '
          'Escribe la ciudad manualmente.',
        ),
      );
    } on GeoServiceException {
      rethrow;
    } catch (e) {
      throw GeoServiceException(
        'Error al obtener coordenadas: ${e.toString()}',
      );
    }
  }

  static Future<String> _reverseGeocodeCity(double lat, double lon) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$lat&lon=$lon'
      '&format=json'
      '&addressdetails=1'
      '&accept-language=es'
      '&zoom=14',
    );

    http.Response resp;
    try {
      resp = await http
          .get(
            uri,
            headers: const {
              'User-Agent': 'ProfioApp/1.0 (profio; contact@profio.app)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      throw const GeoServiceException(
        'No se pudo contactar con el servicio de mapas. '
        'Comprueba tu conexión e inténtalo de nuevo.',
      );
    }

    if (resp.statusCode != 200) {
      throw GeoServiceException(
        'Error al obtener la ciudad (código ${resp.statusCode}).',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final city = GeoCityParser.readCityName(
      data['address'] as Map<String, dynamic>? ?? {},
      data,
    );
    if (city.isEmpty) {
      throw const GeoServiceException(
        'No se pudo identificar la ciudad. Escríbela manualmente.',
      );
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
      '&limit=${limit * 2}'
      '&accept-language=es'
      '&dedupe=1',
    );

    try {
      final resp = await http
          .get(
            uri,
            headers: const {
              'User-Agent': 'ProfioApp/1.0 (profio; contact@profio.app)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as List<dynamic>;

      final seen = <String>{};
      final results = <CitySuggestion>[];

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final suggestion = CitySuggestion.fromNominatimSearch(item);
        if (suggestion == null) continue;
        if (seen.add(suggestion.shortName.toLowerCase())) {
          results.add(suggestion);
        }
        if (results.length >= limit) break;
      }

      return results;
    } catch (_) {
      return [];
    }
  }
}

/// Extracción unificada de nombre de localidad desde respuestas Nominatim.
class GeoCityParser {
  GeoCityParser._();

  static String readCityName(
    Map<String, dynamic> addr,
    Map<String, dynamic> item,
  ) {
    for (final key in [
      'city',
      'town',
      'village',
      'hamlet',
      'municipality',
      'locality',
      'city_district',
      'suburb',
      'county',
    ]) {
      final value = addr[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final name = item['name'];
    if (name is String && name.trim().length >= 2) {
      return name.trim();
    }

    final display = item['display_name'];
    if (display is String && display.isNotEmpty) {
      final first = display.split(',').first.trim();
      if (first.length >= 2) return first;
    }

    return '';
  }

  static String readProvince(Map<String, dynamic> addr) {
    for (final key in ['province', 'state', 'county', 'region']) {
      final value = addr[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}

class CitySuggestion {
  const CitySuggestion({
    required this.shortName,
    required this.displayName,
    this.province,
  });

  /// Lo que se escribe en el campo (solo la ciudad).
  final String shortName;

  /// Lo que se muestra en el desplegable (ciudad + provincia).
  final String displayName;

  final String? province;

  /// Parsea un resultado de búsqueda Nominatim en una sugerencia usable.
  static CitySuggestion? fromNominatimSearch(Map<String, dynamic> item) {
    final addr = (item['address'] as Map<String, dynamic>?) ?? {};
    final city = GeoCityParser.readCityName(addr, item);
    if (city.isEmpty) return null;

    final province = GeoCityParser.readProvince(addr);
    final displayName = province.isNotEmpty && province != city
        ? '$city, $province'
        : city;

    return CitySuggestion(
      shortName: city,
      displayName: displayName,
      province: province.isEmpty ? null : province,
    );
  }
}

class GeoServiceException implements Exception {
  const GeoServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
