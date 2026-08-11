import 'package:buildjobs/core/constants/local_seo.dart';
import 'package:buildjobs/core/constants/profession_catalog.dart';
import 'package:buildjobs/core/utils/slugify.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('slugify', () {
    test('normaliza español', () {
      expect(slugify('Fontanero'), 'fontanero');
      expect(slugify('Albañil'), 'albanil');
      expect(slugify('Madrigal de la Vera'), 'madrigal-de-la-vera');
      expect(slugify('Diseñador de interiores'), 'disenador-de-interiores');
      expect(slugify('Arquitecto técnico'), 'arquitecto-tecnico');
      expect(slugify('Hormigón impreso'), 'hormigon-impreso');
    });
  });

  group('LocalSeo', () {
    test('3 hubs y paths oficio×pueblo únicos', () {
      expect(LocalSeo.locations.length, 3);
      final paths = LocalSeo.allIndexablePaths();
      expect(paths.toSet().length, paths.length);
      expect(paths, contains('/candeleda'));
      expect(paths, contains('/candeleda/fontanero'));
      expect(paths, contains('/villanueva-de-la-vera/albanil'));
      expect(
        paths.length,
        LocalSeo.locations.length *
            (1 + ProfessionCatalog.allProfessions.length),
      );
    });

    test('aliases y resolución de slugs', () {
      expect(LocalSeo.professionBySlug('aparejador')?.name, 'Arquitecto técnico');
      expect(
        LocalSeo.professionBySlug('disenador-de-interiores')?.name,
        'Diseñador de interiores',
      );
      expect(
        LocalSeo.tryCleanSearchPath(
          city: 'Candeleda',
          profession: 'Fontanero',
        ),
        '/candeleda/fontanero',
      );
      expect(
        LocalSeo.tryCleanSearchPath(city: 'Madrigal de la Vera'),
        isNull,
      );
      expect(
        LocalSeo.tryCleanSearchPath(city: 'Madrid', profession: 'Fontanero'),
        isNull,
      );
    });

    test('slugs de oficio del catálogo sin colisiones', () {
      final slugs = ProfessionCatalog.allProfessions
          .map((p) => LocalSeo.professionSlug(p.name))
          .toList();
      expect(slugs.toSet().length, slugs.length);
    });

    test('grafo de vecinos: ≥1, sin autoenlace y simétrico', () {
      for (final loc in LocalSeo.locations) {
        final neighbors = LocalSeo.neighborsOf(loc);
        expect(neighbors, isNotEmpty, reason: loc.slug);
        expect(
          neighbors.every((n) => n.slug != loc.slug),
          isTrue,
          reason: loc.slug,
        );
        expect(neighbors.length, lessThanOrEqualTo(4));
      }

      expect(
        LocalSeo.neighborsOf(LocalSeo.locationBySlug('candeleda')!)
            .map((n) => n.slug),
        containsAll(['madrigal-de-la-vera', 'villanueva-de-la-vera']),
      );

      for (final loc in LocalSeo.locations) {
        for (final neighbor in LocalSeo.neighborsOf(loc)) {
          expect(
            LocalSeo.neighborsOf(neighbor).any((n) => n.slug == loc.slug),
            isTrue,
            reason: '${loc.slug} ↔ ${neighbor.slug}',
          );
        }
      }
    });

    test('formatCityWithProvince añade provincia SEO sin duplicar', () {
      expect(
        LocalSeo.formatCityWithProvince('Villanueva de la Vera'),
        'Villanueva de la Vera, Cáceres',
      );
      expect(
        LocalSeo.formatCityWithProvince('Villanueva De la Vera'),
        'Villanueva de la Vera, Cáceres',
      );
      expect(
        LocalSeo.formatCityWithProvince('Candeleda'),
        'Candeleda, Ávila',
      );
      expect(
        LocalSeo.formatCityWithProvince('Madrigal de la Vera'),
        'Madrigal de la Vera, Cáceres',
      );
      expect(
        LocalSeo.formatCityWithProvince('Villanueva de la Vera, Cáceres'),
        'Villanueva de la Vera, Cáceres',
      );
      expect(LocalSeo.formatCityWithProvince('Madrid'), 'Madrid');
      expect(LocalSeo.formatCityWithProvince(null), '');
      expect(LocalSeo.formatCityWithProvince('  '), '');
    });
  });
}
