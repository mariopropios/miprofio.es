import 'package:buildjobs/core/constants/profession_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfessionCatalog proyecto_diseno', () {
    test('incluye categoría y sección Proyecto y diseño', () {
      final cat = ProfessionCatalog.categoryById('proyecto_diseno');
      expect(cat, isNotNull);
      expect(cat!.title, 'Proyecto y diseño');
      expect(cat.shortName, 'Proyecto');

      final group = ProfessionCatalog.serviceGroupById('proyecto_diseno');
      expect(group, isNotNull);
      expect(group!.categoryIds, ['proyecto_diseno']);
      expect(ProfessionCatalog.serviceSectionGroups.length, 3);
    });

    test('oficios del nicho sin duplicar nombres en allProfessions', () {
      final names = ProfessionCatalog.allNames;
      expect(names.toSet().length, names.length);

      for (final name in [
        'Arquitecto',
        'Arquitecto técnico',
        'Diseñador de interiores',
        'Decorador',
        'Paisajista',
        'Delineante',
        'Diseñador de iluminación',
        'Consultor energético',
      ]) {
        expect(names, contains(name));
        expect(
          ProfessionCatalog.findByName(name)?.categoryId,
          'proyecto_diseno',
        );
      }
    });

    test('professionsForBrowseGroup resuelve oficios del nuevo grupo', () {
      final list =
          ProfessionCatalog.professionsForBrowseGroup('proyecto_diseno');
      expect(list, isNotEmpty);
      expect(list.every((p) => p.categoryId == 'proyecto_diseno'), isTrue);
      expect(list.map((p) => p.name), contains('Arquitecto'));
    });

    test('alias legacy mapean a proyecto_diseno', () {
      expect(
        ProfessionCatalog.categoryForStoredProfession('aparejador')?.id,
        'proyecto_diseno',
      );
      expect(
        ProfessionCatalog.categoryForStoredProfession('interiorismo')?.id,
        'proyecto_diseno',
      );
    });

    test('categorías históricas siguen intactas', () {
      expect(ProfessionCatalog.categoryById('reparaciones'), isNotNull);
      expect(ProfessionCatalog.categoryById('reformas'), isNotNull);
      expect(ProfessionCatalog.categoryById('mantenimiento'), isNotNull);
      expect(ProfessionCatalog.findByName('Fontanero'), isNotNull);
      expect(ProfessionCatalog.findByName('Albañil'), isNotNull);
    });
  });
}
