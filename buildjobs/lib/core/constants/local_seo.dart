import 'profession_catalog.dart';
import '../utils/slugify.dart';
import 'seo_constants.dart';

/// Localidad objetivo SEO (v1: La Vera).
class LocalSeoLocation {
  const LocalSeoLocation({
    required this.slug,
    required this.name,
    required this.regionLabel,
    required this.provinceHint,
  });

  final String slug;
  final String name;

  /// Contexto regional corto, p.ej. "La Vera".
  final String regionLabel;

  /// Pista de provincia para copy (Ávila / Cáceres).
  final String provinceHint;
}

/// SEO local programático: hubs + oficio×pueblo.
abstract final class LocalSeo {
  LocalSeo._();

  static const locations = <LocalSeoLocation>[
    LocalSeoLocation(
      slug: 'candeleda',
      name: 'Candeleda',
      regionLabel: 'La Vera',
      provinceHint: 'Ávila',
    ),
    LocalSeoLocation(
      slug: 'madrigal-de-la-vera',
      name: 'Madrigal de la Vera',
      regionLabel: 'La Vera',
      provinceHint: 'Cáceres',
    ),
    LocalSeoLocation(
      slug: 'villanueva-de-la-vera',
      name: 'Villanueva de la Vera',
      regionLabel: 'La Vera',
      provinceHint: 'Cáceres',
    ),
  ];

  /// Oficios destacados en hubs (subconjunto del catálogo).
  static const popularProfessionNames = <String>[
    'Fontanero',
    'Electricista',
    'Albañil',
    'Pintor',
    'Manitas a domicilio',
    'Jardinero',
    'Arquitecto',
    'Diseñador de interiores',
  ];

  /// Aliases de slug → slug canónico del catálogo.
  static const professionSlugAliases = <String, String>{
    'aparejador': 'arquitecto-tecnico',
    'arquitecto-tecnico-aparejador': 'arquitecto-tecnico',
    'interiorista': 'disenador-de-interiores',
    'disenadora-de-interiores': 'disenador-de-interiores',
    'fontaneria': 'fontanero',
    'electricidad': 'electricista',
    'albanileria': 'albanil',
    'trabajos-en-altura': 'trabajos-verticales',
    'verticalista': 'trabajos-verticales',
    'alpinista-industrial': 'trabajos-verticales',
    'poda-de-altura': 'poda-en-altura',
    'podador': 'poda-en-altura',
    'podador-en-altura': 'poda-en-altura',
    'canalero': 'canalones',
    'canalones-y-bajantes': 'canalones',
    'canalon': 'canalones',
    'fachadista': 'rehabilitacion-de-fachadas',
    'fachadas': 'rehabilitacion-de-fachadas',
    'rehabilitacion-fachadas': 'rehabilitacion-de-fachadas',
    'chimeneas': 'deshollinador',
    'limpieza-de-chimeneas': 'deshollinador',
  };

  static final Map<String, LocalSeoLocation> _bySlug = {
    for (final loc in locations) loc.slug: loc,
  };

  /// Grafo de colindancia SEO v1 (La Vera). Fuente única para hubs/landings.
  /// Máx. razonable por pueblo: 3–4 vecinos.
  static const neighborSlugsBySlug = <String, List<String>>{
    'candeleda': ['madrigal-de-la-vera', 'villanueva-de-la-vera'],
    'madrigal-de-la-vera': ['candeleda', 'villanueva-de-la-vera'],
    'villanueva-de-la-vera': ['candeleda', 'madrigal-de-la-vera'],
  };

  /// Pueblos colindantes de [location] (nunca incluye la propia ciudad).
  static List<LocalSeoLocation> neighborsOf(LocalSeoLocation location) {
    final slugs = neighborSlugsBySlug[location.slug] ?? const <String>[];
    final out = <LocalSeoLocation>[];
    for (final slug in slugs) {
      if (slug == location.slug) continue;
      final loc = _bySlug[slug];
      if (loc != null) out.add(loc);
      if (out.length >= 4) break;
    }
    return List.unmodifiable(out);
  }

  static LocalSeoLocation? locationBySlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    return _bySlug[slugify(slug)];
  }

  static LocalSeoLocation? locationByCityName(String? city) {
    if (city == null || city.trim().isEmpty) return null;
    final needle = slugify(city);
    for (final loc in locations) {
      if (slugify(loc.name) == needle) return loc;
      // "Candeleda, Ávila" etc.
      if (needle.startsWith(loc.slug)) return loc;
    }
    return null;
  }

  /// Presentación UI: `{Ciudad}, {Provincia}` cuando se conoce (SEO La Vera).
  /// No inventa provincias; no duplica si ya viene `Ciudad, …`.
  /// Solo display — no altera el valor guardado en BD.
  static String formatCityWithProvince(String? city) {
    final raw = city?.trim() ?? '';
    if (raw.isEmpty) return '';

    final comma = raw.indexOf(',');
    if (comma >= 0) {
      final before = raw.substring(0, comma).trim();
      final after = raw.substring(comma + 1).trim();
      if (after.isNotEmpty) {
        final loc = locationByCityName(before) ?? locationByCityName(raw);
        if (loc != null) return '${loc.name}, ${loc.provinceHint}';
        return '$before, $after';
      }
    }

    final loc = locationByCityName(raw);
    if (loc != null) return '${loc.name}, ${loc.provinceHint}';
    return raw;
  }

  static bool isLocalSeoCitySlug(String? slug) => locationBySlug(slug) != null;

  static String professionSlug(String professionName) => slugify(professionName);

  static ProfessionItem? professionBySlug(String? slug) {
    if (slug == null || slug.isEmpty) return null;
    var key = slugify(slug);
    key = professionSlugAliases[key] ?? key;
    for (final p in ProfessionCatalog.allProfessions) {
      if (professionSlug(p.name) == key) return p;
    }
    return null;
  }

  static String hubPath(LocalSeoLocation location) => '/${location.slug}';

  static String professionPath(
    LocalSeoLocation location,
    String professionName,
  ) =>
      '/${location.slug}/${professionSlug(professionName)}';

  static String professionPathBySlugs(String citySlug, String professionSlug) =>
      '/$citySlug/$professionSlug';

  /// Si city + oficio coinciden con SEO local, devuelve path limpio oficio×pueblo.
  /// Solo ciudad (sin oficio) → `null` (la app debe quedarse en `/search?city=…`).
  /// Los hubs (`/candeleda`, etc.) siguen existiendo por URL directa / sitemap.
  static String? tryCleanSearchPath({
    String? city,
    String? profession,
  }) {
    final loc = locationByCityName(city);
    if (loc == null) return null;
    if (profession == null || profession.trim().isEmpty) return null;

    final item = ProfessionCatalog.findByName(profession.trim()) ??
        professionBySlug(profession);
    if (item == null) return null;
    return professionPath(loc, item.name);
  }

  static String hubTitle(LocalSeoLocation location) =>
      'Profesionales del hogar en ${location.name} | ${SeoConstants.siteName}';

  static String hubDescription(LocalSeoLocation location) =>
      'Encuentra fontaneros, electricistas, albañiles y más profesionales '
      'del hogar en ${location.name} (${location.regionLabel}). '
      'Compara reseñas y contacta gratis en ${SeoConstants.siteName}.';

  static String hubH1(LocalSeoLocation location) =>
      'Profesionales del hogar en ${location.name}';

  static String hubIntro(LocalSeoLocation location) =>
      'Fontaneros, electricistas, reformas y más en ${location.name} '
      '(${location.regionLabel}). Compara reseñas y contacta gratis.';

  static String professionTitle(
    LocalSeoLocation location,
    String professionName,
  ) =>
      '$professionName en ${location.name} | ${SeoConstants.siteName}';

  static String professionDescription(
    LocalSeoLocation location,
    String professionName,
  ) =>
      'Encuentra $professionName con reseñas en ${location.name} '
      '(${location.regionLabel}). Compara perfiles, distancia y contacta gratis.';

  static String professionH1(
    LocalSeoLocation location,
    String professionName,
  ) =>
      '$professionName en ${location.name}';

  static String professionIntro(
    LocalSeoLocation location,
    String professionName,
  ) =>
      'Perfiles con reseñas cerca de ${location.name}. '
      'Toca una ficha para ver fotos y contactar.';

  static String emptyProfessionMessage(
    LocalSeoLocation location,
    String professionName,
  ) =>
      'Todavía no hay ningún $professionName publicado en ${location.name}. '
      'Si eres tú, publica tu perfil gratis y sé el primero.';

  /// Todas las URLs indexables v1 (hubs + oficio×pueblo).
  static List<String> allIndexablePaths() {
    final paths = <String>[];
    for (final loc in locations) {
      paths.add(hubPath(loc));
      for (final p in ProfessionCatalog.allProfessions) {
        paths.add(professionPath(loc, p.name));
      }
    }
    return paths;
  }
}
