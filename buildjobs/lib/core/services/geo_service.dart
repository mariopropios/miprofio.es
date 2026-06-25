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
      throw GeoServiceException(
          'Los servicios de ubicación están desactivados.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw GeoServiceException('Permiso de ubicación denegado.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw GeoServiceException(
          'Permiso de ubicación denegado permanentemente. '
          'Actívalo desde los ajustes del dispositivo.');
    }

    // 2. Obtener posición
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 10),
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
      headers: {'User-Agent': 'HomeCheckApp/1.0'},
    ).timeout(const Duration(seconds: 8));

    if (resp.statusCode != 200) {
      throw GeoServiceException('Error al obtener la ciudad (Nominatim).');
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
      throw GeoServiceException('No se pudo identificar la ciudad.');
    }

    return city;
  }
}

class GeoServiceException implements Exception {
  const GeoServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}
