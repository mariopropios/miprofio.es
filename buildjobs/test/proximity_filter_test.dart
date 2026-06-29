import 'package:buildjobs/core/utils/geo_distance.dart';
import 'package:buildjobs/core/utils/proximity_filter.dart';
import 'package:buildjobs/shared/models/professional.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeoDistance', () {
    test('Villanueva de la Vera ↔ Candeleda está a menos de 50 km', () {
      // Coordenadas aproximadas de los municipios (centro).
      const villanuevaLat = 40.1461;
      const villanuevaLon = -5.4606;
      const candeledaLat = 40.1578;
      const candeledaLon = -5.2417;

      final km = GeoDistance.haversineKm(
        lat1: villanuevaLat,
        lon1: villanuevaLon,
        lat2: candeledaLat,
        lon2: candeledaLon,
      );

      expect(km, greaterThan(10));
      expect(km, lessThan(50));
    });
  });

  group('ProximityFilter', () {
    Professional pro({
      required double lat,
      required double lon,
      required int radiusKm,
      String city = 'Villanueva de la Vera, Cáceres',
    }) {
      return Professional(
        id: '1',
        name: 'Test',
        profession: 'Albañil',
        city: city,
        rating: 4.5,
        reviewCount: 10,
        address: city,
        latitude: lat,
        longitude: lon,
        serviceRadiusKm: radiusKm,
      );
    }

    test('profesional en Villanueva con 50 km aparece al buscar Candeleda', () {
      const searchLat = 40.1578;
      const searchLng = -5.2417;

      final professional = pro(
        lat: 40.1461,
        lon: -5.4606,
        radiusKm: 50,
      );

      expect(
        ProximityFilter.matches(
          professional: professional,
          searchLat: searchLat,
          searchLng: searchLng,
          searchCityLabel: 'Candeleda, Ávila',
        ),
        isTrue,
      );
    });

    test('profesional en Madrid con 25 km NO aparece al buscar Candeleda', () {
      const searchLat = 40.1578;
      const searchLng = -5.2417;

      final professional = pro(
        lat: 40.4168,
        lon: -3.7038,
        radiusKm: 25,
        city: 'Madrid',
      );

      expect(
        ProximityFilter.matches(
          professional: professional,
          searchLat: searchLat,
          searchLng: searchLng,
          searchCityLabel: 'Candeleda, Ávila',
        ),
        isFalse,
      );
    });

    test('sin coordenadas hace fallback por nombre de localidad', () {
      final professional = Professional(
        id: '2',
        name: 'Legacy',
        profession: 'Pintor',
        city: 'Candeleda',
        rating: 4,
        reviewCount: 1,
        address: 'Candeleda',
        serviceRadiusKm: 25,
      );

      expect(
        ProximityFilter.matches(
          professional: professional,
          searchLat: 40.1578,
          searchLng: -5.2417,
          searchCityLabel: 'Candeleda, Ávila',
        ),
        isTrue,
      );
    });

    test('citiesMatch ignora provincia', () {
      expect(
        citiesMatch('Candeleda, Ávila', 'Candeleda'),
        isTrue,
      );
      expect(
        citiesMatch('Villanueva de la Vera, Cáceres', 'Candeleda'),
        isFalse,
      );
    });
  });
}
