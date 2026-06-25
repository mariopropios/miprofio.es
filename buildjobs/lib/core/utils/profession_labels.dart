/// Utilidades para oficios múltiples almacenados como texto separado por comas.
class ProfessionLabels {
  ProfessionLabels._();

  static const separator = ', ';

  static List<String> parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static String join(Iterable<String> professions) {
    return professions.map((p) => p.trim()).where((p) => p.isNotEmpty).join(separator);
  }

  static bool includes(String? raw, String profession) {
    final target = profession.trim().toLowerCase();
    return parse(raw).any((p) => p.toLowerCase() == target);
  }
}
