class ProfessionItem {
  const ProfessionItem({
    required this.name,
    required this.description,
    required this.categoryId,
  });

  final String name;
  final String description;
  final String categoryId;
}

class ProfessionCategory {
  const ProfessionCategory({
    required this.id,
    required this.shortName,
    required this.title,
    required this.professions,
  });

  final String id;
  final String shortName;
  final String title;
  final List<ProfessionItem> professions;
}

class ProfessionCatalog {
  ProfessionCatalog._();

  static const categories = <ProfessionCategory>[
    // ─── 1. Reparaciones Técnicas ────────────────────────────────────────────
    ProfessionCategory(
      id: 'reparaciones',
      shortName: 'Reparaciones',
      title: 'Reparaciones Técnicas',
      professions: [
        ProfessionItem(
          categoryId: 'reparaciones',
          name: 'Fontanero',
          description:
              'Reparación de tuberías, humedades, grifería y desagües.',
        ),
        ProfessionItem(
          categoryId: 'reparaciones',
          name: 'Electricista',
          description:
              'Cuadros eléctricos, cableado general, iluminación y boletines oficiales.',
        ),
        ProfessionItem(
          categoryId: 'reparaciones',
          name: 'Cerrajero',
          description:
              'Apertura de puertas de urgencia, cambio de cerraduras y rejas de seguridad.',
        ),
        ProfessionItem(
          categoryId: 'reparaciones',
          name: 'Reparación de Electrodomésticos',
          description:
              'Servicio técnico de lavadoras, hornos, neveras, lavavajillas y secadoras.',
        ),
        ProfessionItem(
          categoryId: 'reparaciones',
          name: 'Climatización',
          description:
              'Instalación y mantenimiento de aire acondicionado, calderas y aerotermia.',
        ),
        ProfessionItem(
          categoryId: 'reparaciones',
          name: 'Antenista',
          description:
              'Instalación y configuración de antenas de TV, redes Wi-Fi y telecomunicaciones.',
        ),
        ProfessionItem(
          categoryId: 'reparaciones',
          name: 'Pocero',
          description:
              'Limpieza de fosas sépticas, arquetas y desatascos generales.',
        ),
      ],
    ),

    // ─── 2. Reformas y Acabados ──────────────────────────────────────────────
    ProfessionCategory(
      id: 'reformas',
      shortName: 'Reformas',
      title: 'Reformas y Acabados',
      professions: [
        // También en Reparaciones: aquí se muestran como parte de reforma integral
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Fontanero',
          description:
              'Instalación de fontanería nueva en baños, cocinas y reformas integrales.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Electricista',
          description:
              'Instalación eléctrica completa en obras, reformas y locales comerciales.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Climatización',
          description:
              'Instalación de aire acondicionado, suelo radiante y aerotermia en reformas.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Albañil',
          description:
              'Construcción de tabiques, cimientos, ladrillo y reformas estructurales.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Pintor',
          description:
              'Alisado de gotelé, pintura decorativa, empapelado y microcemento.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Carpintero (Madera)',
          description:
              'Puertas de paso, armarios a medida, muebles de cocina y tarimas.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Pladurista',
          description:
              'Montaje de falsos techos, tabiquería seca y aislamiento acústico con pladur.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Ventanas y Cerramientos',
          description:
              'Instalación de ventanas climalit, puertas de aluminio/PVC y cerramientos térmicos.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Alicatador',
          description:
              'Colocación de azulejos, cerámicas y suelos porcelánicos.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Parquetista',
          description:
              'Instalación de tarimas, suelos de madera, lijado y barnizado.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Cristalero',
          description:
              'Espejos a medida, mamparas de ducha y cristales de seguridad.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Techador',
          description:
              'Instalación de tejas, impermeabilización de azoteas y reparación de goteras.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Mampostero',
          description:
              'Especialistas en muros de piedra natural y fachadas tradicionales.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Desescombro',
          description:
              'Demoliciones seguras, retirada de escombros y limpieza de obra.',
        ),
      ],
    ),

    // ─── 3. Mantenimiento General ────────────────────────────────────────────
    ProfessionCategory(
      id: 'mantenimiento',
      shortName: 'Mantenimiento',
      title: 'Mantenimiento General',
      professions: [
        ProfessionItem(
          categoryId: 'mantenimiento',
          name: 'Manitas a domicilio',
          description:
              'Pequeños arreglos del hogar: colgar cuadros, montar muebles y reparaciones varias.',
        ),
        ProfessionItem(
          categoryId: 'mantenimiento',
          name: 'Limpieza Fin de Obra',
          description:
              'Limpieza intensiva tras reformas o construcciones, retirando polvo y residuos.',
        ),
        ProfessionItem(
          categoryId: 'mantenimiento',
          name: 'Jardinero',
          description:
              'Mantenimiento de jardines, podas, césped artificial y sistemas de riego.',
        ),
        ProfessionItem(
          categoryId: 'mantenimiento',
          name: 'Persianista',
          description:
              'Reparación, instalación y motorización de persianas, estores y toldos.',
        ),
        ProfessionItem(
          categoryId: 'mantenimiento',
          name: 'Piscina',
          description:
              'Construcción de piscinas de obra, depuradoras, mantenimiento y tratamientos.',
        ),
        ProfessionItem(
          categoryId: 'mantenimiento',
          name: 'Limpia-Cristales',
          description:
              'Limpieza profesional de cristales en altura y grandes cristaleras.',
        ),
      ],
    ),
  ];

  /// Lista sin duplicados (un oficio puede aparecer en varias categorías).
  static List<ProfessionItem> get allProfessions {
    final seen = <String>{};
    return categories.expand((c) => c.professions).where((p) {
      return seen.add(p.name);
    }).toList();
  }

  static List<String> get allNames =>
      allProfessions.map((p) => p.name).toList();

  static ProfessionCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  static ProfessionItem? findByName(String name) {
    for (final p in allProfessions) {
      if (p.name == name) return p;
    }
    return null;
  }

  /// Devuelve los nombres de profesiones del catálogo que guardan relación
  /// semántica con [query]. Usa coincidencia de prefijo (≥5 chars) contra el
  /// nombre y la descripción de cada oficio para cubrir variaciones morfológicas
  /// del español (limpiar → limpieza, fontanería → fontanero, etc.).
  static List<String> relatedProfessionNames(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    // Palabras del query con al menos 4 caracteres (ignorar preposiciones, etc.)
    final qWords = q
        .split(RegExp(r'[\s,;]+'))
        .where((w) => w.length >= 4)
        .toList();
    if (qWords.isEmpty) return [];

    bool _matchesTerm(String term, String text) {
      if (text.contains(term)) return true;
      // Coincidencia por prefijo: los primeros 5 caracteres comunes
      final prefix = term.length >= 5 ? term.substring(0, 5) : term;
      return text.split(RegExp(r'[\s/,()]+')).any((w) => w.startsWith(prefix));
    }

    return allProfessions.where((p) {
      final combined = '${p.name} ${p.description}'.toLowerCase();
      return qWords.any((word) => _matchesTerm(word, combined));
    }).map((p) => p.name).toList();
  }

  /// Busca la categoría de un oficio guardado con nombre antiguo.
  /// Útil para retrocompatibilidad con datos ya almacenados en Supabase.
  static ProfessionCategory? categoryForStoredProfession(String stored) {
    final lower = stored.toLowerCase();
    for (final cat in categories) {
      for (final p in cat.professions) {
        if (p.name.toLowerCase() == lower) return cat;
      }
    }
    // Alias de nombres anteriores → categoría actual
    const legacyMap = <String, String>{
      'electrodomésticos': 'reparaciones',
      'manitas (handyman)': 'mantenimiento',
      'fin de obra': 'mantenimiento',
      'carpintero (aluminio/pvc)': 'reformas',
      'estructura': 'reformas',
      'exteriores': 'mantenimiento',
      'servicios': 'mantenimiento',
      'instalaciones': 'reparaciones',
      'acabados': 'reformas',
    };
    final mapped = legacyMap[lower];
    if (mapped != null) return categoryById(mapped);
    return null;
  }
}
