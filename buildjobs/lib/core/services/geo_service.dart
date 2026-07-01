import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../constants/seo_constants.dart';

/// Servicio de geolocalización multiplataforma (web, Android, iOS).
class GeoService {
  static const _detectTimeout = Duration(seconds: 40);

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

  /// Ciudad, dirección y coordenadas a partir del GPS del dispositivo.
  static Future<GeoLocationResult> detectLocation() {
    return _detectLocationImpl().timeout(
      _detectTimeout,
      onTimeout: () => throw const GeoServiceException(
        'La detección tardó demasiado. Escribe la dirección manualmente '
        'o comprueba que el navegador tenga permiso de ubicación.',
      ),
    );
  }

  static Future<GeoLocationResult> _detectLocationImpl() async {
    await _ensureLocationPermission(userInitiated: true);
    final pos = await _resolveHighAccuracyPosition();
    return _reverseGeocodeFull(pos.latitude, pos.longitude);
  }

  /// Valida una calle/dirección escrita a mano (número opcional).
  static bool isValidStreetInput(String? value) {
    return (value?.trim().length ?? 0) >= 3;
  }

  static String? streetInputError(String? value) {
    if (isValidStreetInput(value)) return null;
    return 'Indica la calle donde trabajas';
  }

  /// Validador para calle opcional: solo exige formato si el usuario escribe algo.
  static String? optionalStreetInputError(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (isValidStreetInput(trimmed)) return null;
    return 'Si indicas calle, escribe al menos 3 caracteres';
  }

  /// Geocodifica el centro de una localidad (sin calle).
  static Future<GeocodeResult> geocodeCity(String city) async {
    final locality = _cityNameOnly(city.trim());
    if (locality.length < 2) {
      throw const GeoServiceException('Indica la localidad.');
    }

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent('$locality, España')}'
      '&format=json'
      '&addressdetails=1'
      '&countrycodes=es'
      '&limit=1'
      '&accept-language=es',
    );

    http.Response resp;
    try {
      resp = await http
          .get(
            uri,
            headers: const {
              'User-Agent': SeoConstants.publicUserAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      throw const GeoServiceException(
        'No se pudo contactar con el servicio de mapas.',
      );
    }

    if (resp.statusCode != 200) {
      throw GeoServiceException(
        'Error al geocodificar la localidad (código ${resp.statusCode}).',
      );
    }

    final data = jsonDecode(resp.body) as List<dynamic>;
    if (data.isEmpty) {
      throw GeoServiceException(
        'No se encontró "$locality". Revisa el nombre de la localidad.',
      );
    }

    final item = data.first as Map<String, dynamic>;
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat == null || lon == null) {
      throw const GeoServiceException(
        'No se pudieron obtener las coordenadas de la localidad.',
      );
    }

    return GeocodeResult(
      latitude: lat,
      longitude: lon,
      formattedAddress: locality,
    );
  }

  /// Resuelve coordenadas: GPS previo, calle o solo localidad.
  static Future<GeocodeResult> resolveCoordinates({
    required String city,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    if (latitude != null && longitude != null) {
      return GeocodeResult(
        latitude: latitude,
        longitude: longitude,
        formattedAddress: address?.trim().isNotEmpty == true
            ? address!.trim()
            : _cityNameOnly(city),
      );
    }

    final street = address?.trim() ?? '';
    if (street.length >= 3) {
      return geocodeAddress(address: street, city: city);
    }

    return geocodeCity(city);
  }

  /// Geocodifica una dirección postal dentro de una ciudad (España).
  static Future<GeocodeResult> geocodeAddress({
    required String address,
    required String city,
  }) async {
    final street = address.trim();
    final locality = city.trim();
    if (street.length < 3 || locality.length < 2) {
      throw const GeoServiceException(
        'Indica la calle y la ciudad.',
      );
    }

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent('$street, $locality, España')}'
      '&format=json'
      '&addressdetails=1'
      '&countrycodes=es'
      '&limit=1'
      '&accept-language=es',
    );

    http.Response resp;
    try {
      resp = await http
          .get(
            uri,
            headers: const {
              'User-Agent': SeoConstants.publicUserAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      throw const GeoServiceException(
        'No se pudo contactar con el servicio de mapas.',
      );
    }

    if (resp.statusCode != 200) {
      throw GeoServiceException(
        'Error al geocodificar la dirección (código ${resp.statusCode}).',
      );
    }

    final data = jsonDecode(resp.body) as List<dynamic>;
    if (data.isEmpty) {
      throw const GeoServiceException(
        'No se encontró esa dirección. Revisa calle y ciudad.',
      );
    }

    final item = data.first as Map<String, dynamic>;
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat == null || lon == null) {
      throw const GeoServiceException(
        'No se pudieron obtener las coordenadas de la dirección.',
      );
    }

    final addr = (item['address'] as Map<String, dynamic>?) ?? {};
    final formatted = GeoCityParser.readStreetAddress(addr);
    final display = item['display_name'] as String?;

    return GeocodeResult(
      latitude: lat,
      longitude: lon,
      formattedAddress: formatted.isNotEmpty
          ? formatted
          : (display?.split(',').first.trim() ?? street),
    );
  }

  static Future<GeoLocationResult> _reverseGeocodeFull(
    double lat,
    double lon,
  ) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$lat&lon=$lon'
      '&format=json'
      '&addressdetails=1'
      '&accept-language=es'
      '&zoom=18',
    );

    http.Response resp;
    try {
      resp = await http
          .get(
            uri,
            headers: const {
              'User-Agent': SeoConstants.publicUserAgent,
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
        'Error al obtener la ubicación (código ${resp.statusCode}).',
      );
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final addr = data['address'] as Map<String, dynamic>? ?? {};
    final city = GeoCityParser.readCityDisplayName(addr, data);
    if (city.isEmpty) {
      throw const GeoServiceException(
        'No se pudo identificar la ciudad. Escríbela manualmente.',
      );
    }

    var street = GeoCityParser.readStreetAddress(addr, item: data);

    return GeoLocationResult(
      city: city,
      address: street,
      latitude: lat,
      longitude: lon,
    );
  }

  static Future<String> _detectCityImpl() async {
    final location = await detectLocation();
    return location.city;
  }

  static Future<void> _ensureLocationPermission({
    bool userInitiated = true,
  }) async {
    if (!kIsWeb) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const GeoServiceException(
          'Los servicios de ubicación están desactivados.',
          failure: GeoServiceFailure.locationDisabled,
        );
      }
    }

    var permission = await Geolocator.checkPermission();

    if (!_isPermissionGranted(permission) && userInitiated) {
      // Cada pulsación del usuario vuelve a solicitar permiso (también tras denegar).
      permission = await _requestPermissionWithTimeout();
    } else if (permission == LocationPermission.denied) {
      permission = await _requestPermissionWithTimeout();
    }

    if (_isPermissionGranted(permission)) return;

    // En web móvil, getCurrentPosition en gesto de usuario puede reabrir el
    // diálogo del navegador aunque checkPermission siga en denied/deniedForever.
    if (kIsWeb && userInitiated) return;

    if (permission == LocationPermission.deniedForever) {
      throw const GeoServiceException(
        'Permiso de ubicación bloqueado. Actívalo en los ajustes '
        'del navegador o del dispositivo.',
        failure: GeoServiceFailure.permissionBlocked,
      );
    }

    throw const GeoServiceException(
      'Permiso de ubicación denegado. Pulsa de nuevo y acepta '
      'cuando el navegador lo solicite.',
      failure: GeoServiceFailure.permissionDenied,
    );
  }

  static bool _isPermissionGranted(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  static Future<LocationPermission> _requestPermissionWithTimeout() async {
    try {
      return await Geolocator.requestPermission().timeout(
        const Duration(seconds: 30),
        onTimeout: () => LocationPermission.denied,
      );
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  static LocationSettings get _highAccuracySettings {
    if (kIsWeb) {
      return WebSettings(
        accuracy: LocationAccuracy.high,
        maximumAge: const Duration(seconds: 60),
        timeLimit: const Duration(seconds: 30),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 18),
    );
  }

  static Future<Position> _resolveHighAccuracyPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: _highAccuracySettings,
      ).timeout(
        Duration(seconds: kIsWeb ? 35 : 20),
        onTimeout: () => throw const GeoServiceException(
          'No se pudo obtener la ubicación a tiempo. '
          'Comprueba el GPS o escribe la dirección manualmente.',
          failure: GeoServiceFailure.timeout,
        ),
      );
    } on GeoServiceException {
      rethrow;
    } catch (e) {
      throw _mapPositionError(e);
    }
  }

  static GeoServiceException _mapPositionError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('denied') || msg.contains('permission')) {
      final blocked = msg.contains('forever') ||
          msg.contains('blocked') ||
          msg.contains('not allowed');
      return GeoServiceException(
        blocked
            ? 'Permiso de ubicación bloqueado. Actívalo en los ajustes '
                'del navegador o del dispositivo.'
            : 'Permiso de ubicación denegado. Pulsa de nuevo y acepta '
                'cuando el navegador lo solicite.',
        failure: blocked
            ? GeoServiceFailure.permissionBlocked
            : GeoServiceFailure.permissionDenied,
      );
    }
    return GeoServiceException(
      'Error al obtener coordenadas: ${e.toString()}',
    );
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
              'User-Agent': SeoConstants.publicUserAgent,
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
        // Deduplicar por displayName para que "Candeleda, Ávila" y
        // "Candeleda, Cáceres" puedan aparecer como entradas distintas.
        if (seen.add(suggestion.displayName.toLowerCase())) {
          results.add(suggestion);
        }
        if (results.length >= limit) break;
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  /// Busca calles/direcciones dentro de [city] (mín. 2 caracteres en [query]).
  static Future<List<AddressSuggestion>> searchAddresses({
    required String city,
    required String query,
    int limit = 6,
    String countryCode = 'es',
  }) async {
    final streetQuery = query.trim();
    final cityName = _cityNameOnly(city);
    if (streetQuery.length < 2 || cityName.length < 2) return [];

    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent('$streetQuery, $cityName, España')}'
      '&format=json'
      '&addressdetails=1'
      '&countrycodes=$countryCode'
      '&limit=${limit * 3}'
      '&accept-language=es'
      '&dedupe=1',
    );

    try {
      final resp = await http
          .get(
            uri,
            headers: const {
              'User-Agent': SeoConstants.publicUserAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as List<dynamic>;
      final seen = <String>{};
      final results = <AddressSuggestion>[];

      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final suggestion = AddressSuggestion.fromNominatimSearch(item, cityName);
        if (suggestion == null) continue;
        final key = suggestion.streetAddress.toLowerCase();
        if (seen.add(key)) {
          results.add(suggestion);
        }
        if (results.length >= limit) break;
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  /// Extrae solo el nombre de ciudad de "Ciudad, Provincia".
  static String _cityNameOnly(String city) {
    final trimmed = city.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(',').first.trim();
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

  static String readCityDisplayName(
    Map<String, dynamic> addr,
    Map<String, dynamic> item,
  ) {
    final city = readCityName(addr, item);
    if (city.isEmpty) return '';
    final province = readProvince(addr);
    if (province.isNotEmpty && province != city) {
      return '$city, $province';
    }
    return city;
  }

  static String readStreetAddress(
    Map<String, dynamic> addr, {
    Map<String, dynamic>? item,
  }) {
    for (final key in [
      'road',
      'street',
      'pedestrian',
      'residential',
      'living_street',
      'footway',
      'path',
      'cycleway',
    ]) {
      final value = addr[key];
      if (value is String && value.trim().isNotEmpty) {
        final road = value.trim();
        final number = addr['house_number'];
        if (number is String && number.trim().isNotEmpty) {
          return '$road ${number.trim()}';
        }
        return road;
      }
    }

    for (final key in ['building', 'amenity', 'place', 'commercial']) {
      final value = addr[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final display = item?['display_name'];
    if (display is String && display.isNotEmpty) {
      final first = display.split(',').first.trim();
      if (first.length >= 3) return first;
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

class AddressSuggestion {
  const AddressSuggestion({
    required this.streetAddress,
    required this.displayName,
    this.latitude,
    this.longitude,
  });

  /// Valor que se guarda en el campo (calle y número).
  final String streetAddress;

  /// Texto mostrado en el desplegable.
  final String displayName;

  final double? latitude;
  final double? longitude;

  static AddressSuggestion? fromNominatimSearch(
    Map<String, dynamic> item,
    String cityContext,
  ) {
    final addr = (item['address'] as Map<String, dynamic>?) ?? {};
    final street = GeoCityParser.readStreetAddress(addr);
    if (street.isEmpty) return null;

    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');

    final suburb = addr['suburb'] ?? addr['neighbourhood'] ?? addr['quarter'];
    final postcode = addr['postcode'];

    final parts = <String>[street];
    if (suburb is String && suburb.trim().isNotEmpty) {
      parts.add(suburb.trim());
    }
    if (postcode is String && postcode.trim().isNotEmpty) {
      parts.add(postcode.trim());
    }
    parts.add(cityContext);

    return AddressSuggestion(
      streetAddress: street,
      displayName: parts.join(', '),
      latitude: lat,
      longitude: lon,
    );
  }
}

class GeoServiceException implements Exception {
  const GeoServiceException(
    this.message, {
    this.failure = GeoServiceFailure.other,
  });

  final String message;
  final GeoServiceFailure failure;

  @override
  String toString() => message;
}

enum GeoServiceFailure {
  permissionDenied,
  permissionBlocked,
  locationDisabled,
  timeout,
  other,
}

class GeoLocationResult {
  const GeoLocationResult({
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String city;
  final String address;
  final double latitude;
  final double longitude;
}

class GeocodeResult {
  const GeocodeResult({
    required this.latitude,
    required this.longitude,
    this.formattedAddress,
  });

  final double latitude;
  final double longitude;
  final String? formattedAddress;
}
