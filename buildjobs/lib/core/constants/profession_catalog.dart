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

/// Agrupa categorías del catálogo para el registro (ej. Reparaciones + Reformas).
class ServiceSectionGroup {
  const ServiceSectionGroup({
    required this.id,
    required this.label,
    required this.title,
    required this.categoryIds,
  });

  final String id;
  final String label;
  final String title;
  final List<String> categoryIds;
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
        ProfessionItem(
          categoryId: 'reparaciones',
          name: 'Impermeabilizador',
          description:
              'Reparación de goteras, filtraciones y humedades en paredes, cubiertas y garajes.',
        ),
        ProfessionItem(
          categoryId: 'reparaciones',
          name: 'Instalador Solar',
          description:
              'Instalación de paneles solares fotovoltaicos, baterías y sistemas de autoconsumo.',
        ),
        ProfessionItem(
          categoryId: 'reparaciones',
          name: 'Herrero',
          description:
              'Rejas, puertas metálicas, soldadura, barandillas y reparación de estructuras de hierro.',
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
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Impermeabilizador',
          description:
              'Impermeabilización de cubiertas planas, terrazas, sótanos y muros de fachada.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Instalador Solar',
          description:
              'Integración de energía solar en reformas y obra nueva: fotovoltaica y térmica.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Solador',
          description:
              'Colocación de suelos de hormigón pulido, microcemento y suelos industriales.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Herrero',
          description:
              'Estructuras metálicas, barandillas, puertas correderas y cerramientos de hierro en obra.',
        ),
        ProfessionItem(
          categoryId: 'reformas',
          name: 'Andamiero',
          description:
              'Montaje y desmontaje de andamios, vallados de obra y plataformas de trabajo en altura.',
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
        ProfessionItem(
          categoryId: 'mantenimiento',
          name: 'Desbrozador',
          description:
              'Limpieza de parcelas y solares, desbrozado de maleza, tala menor y gestión de terrenos con maquinaria.',
        ),
        ProfessionItem(
          categoryId: 'mantenimiento',
          name: 'Control de Plagas',
          description:
              'Fumigación y desinfección contra cucarachas, ratas, termitas, avispas y otras plagas del hogar.',
        ),
        ProfessionItem(
          categoryId: 'mantenimiento',
          name: 'Técnico de Ascensores',
          description:
              'Mantenimiento, revisión legal y reparación de ascensores y montacargas.',
        ),
        ProfessionItem(
          categoryId: 'mantenimiento',
          name: 'Instalador de Riego',
          description:
              'Diseño e instalación de sistemas de riego por goteo, aspersión y automatizados.',
        ),
      ],
    ),
  ];

  /// Secciones de servicio para registro y búsqueda (Reparaciones+Reformas unidas).
  static const serviceSectionGroups = <ServiceSectionGroup>[
    ServiceSectionGroup(
      id: 'reparacion_reforma',
      label: 'Reparaciones y Reformas',
      title: 'Reparaciones y Reformas',
      categoryIds: ['reparaciones', 'reformas'],
    ),
    ServiceSectionGroup(
      id: 'mantenimiento',
      label: 'Mantenimiento',
      title: 'Mantenimiento General',
      categoryIds: ['mantenimiento'],
    ),
  ];

  static ServiceSectionGroup? serviceGroupById(String id) {
    for (final g in serviceSectionGroups) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Oficios visibles al navegar por sección (sin duplicados).
  static List<ProfessionItem> professionsForBrowseGroup(String groupId) {
    final group = serviceGroupById(groupId);
    if (group == null) return const [];

    final seen = <String>{};
    final result = <ProfessionItem>[];
    for (final categoryId in group.categoryIds) {
      final cat = categoryById(categoryId);
      if (cat == null) continue;
      for (final prof in cat.professions) {
        if (seen.add(prof.name)) result.add(prof);
      }
    }
    return result;
  }

  static bool isServiceGroupSelected(
    ServiceSectionGroup group,
    Set<String> selectedCategoryIds,
  ) =>
      group.categoryIds.any(selectedCategoryIds.contains);

  static Set<String> toggleServiceGroup(
    ServiceSectionGroup group,
    Set<String> selectedCategoryIds,
  ) {
    final next = Set<String>.from(selectedCategoryIds);
    if (isServiceGroupSelected(group, selectedCategoryIds)) {
      next.removeAll(group.categoryIds);
    } else {
      next.addAll(group.categoryIds);
    }
    return next;
  }

  /// Etiquetas agrupadas para la vista previa del perfil.
  static List<String> serviceSectionLabels(Set<String> categoryIds) {
    return serviceSectionGroups
        .where((g) => isServiceGroupSelected(g, categoryIds))
        .map((g) => g.label)
        .toList();
  }

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

  static List<String> relatedProfessionNames(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    // Palabras del query con al menos 4 caracteres (ignorar preposiciones, etc.)
    final qWords = q
        .split(RegExp(r'[\s,;]+'))
        .where((w) => w.length >= 4)
        .toList();
    if (qWords.isEmpty) return [];

    bool matchesTerm(String term, String text) {
      if (text.contains(term)) return true;
      // Coincidencia por prefijo: los primeros 5 caracteres comunes
      final prefix = term.length >= 5 ? term.substring(0, 5) : term;
      return text.split(RegExp(r'[\s/,()]+')).any((w) => w.startsWith(prefix));
    }

    return allProfessions.where((p) {
      final combined = '${p.name} ${p.description}'.toLowerCase();
      return qWords.any((word) => matchesTerm(word, combined));
    }).map((p) => p.name).toList();
  }

  /// Oficios del catálogo cuyo nombre o descripción contiene [query].
  static List<ProfessionItem> matchingProfessions(
    String query, {
    int limit = 6,
  }) {
    final q = query.toLowerCase().trim();
    if (q.length < 2) return [];

    final scored = <({ProfessionItem item, int score})>[];
    final seen = <String>{};

    for (final p in allProfessions) {
      final name = p.name.toLowerCase();
      var score = 0;
      if (name.startsWith(q)) {
        score = 3;
      } else if (name.contains(q)) {
        score = 2;
      } else if (p.description.toLowerCase().contains(q)) {
        score = 1;
      } else {
        continue;
      }
      if (seen.add(p.name)) {
        scored.add((item: p, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((e) => e.item).toList();
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
      // nuevos alias de búsqueda
      'impermeabilización': 'reformas',
      'gotera': 'reparaciones',
      'humedad': 'reparaciones',
      'desbrozadora': 'mantenimiento',
      'desbroce': 'mantenimiento',
      'parcela': 'mantenimiento',
      'solar fotovoltaico': 'reparaciones',
      'placas solares': 'reparaciones',
      'plagas': 'mantenimiento',
      'fumigación': 'mantenimiento',
      'ascensor': 'mantenimiento',
      'riego': 'mantenimiento',
      'herrero': 'reparaciones',
      'herrería': 'reparaciones',
      'herreria': 'reparaciones',
      'soldador': 'reparaciones',
      'andamio': 'reformas',
      'andamiaje': 'reformas',
      'andamiero': 'reformas',
      'vallado': 'reformas',
      'vallamiento': 'reformas',
    };
    final mapped = legacyMap[lower];
    if (mapped != null) return categoryById(mapped);
    return null;
  }
}
