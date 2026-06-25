/// Validación de números de móvil españoles (formato nacional e internacional).
class SpanishPhoneValidator {
  SpanishPhoneValidator._();

  /// Prefijos móviles válidos en España (6xx y 7xx).
  static final RegExp _mobilePattern = RegExp(r'^[67]\d{8}$');

  /// Secuencias obviamente falsas (mismo dígito repetido).
  static final RegExp _repeatedDigit = RegExp(r'^(\d)\1{8}$');

  static bool _isTrivialFake(String digits) {
    if (_repeatedDigit.hasMatch(digits)) return true;
    if (digits == '123456789' || digits == '987654321') return true;

    for (var i = 0; i <= 9; i++) {
      final ch = i.toString();
      if (digits.split(ch).length - 1 >= 6) return true;
    }
    return false;
  }

  /// Agrupa dígitos de 3 en 3: 612345678 → 612 345 678
  static String groupEveryThree(String digits) {
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Formatea mientras se escribe (nacional o +34).
  static String formatAsYouType(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed == '+') return '+';

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return trimmed.startsWith('+') ? '+' : '';
    }

    final useInternational = trimmed.startsWith('+') ||
        digits.startsWith('0034') ||
        (digits.startsWith('34') && digits.length > 9);

    if (useInternational) {
      var national = digits;
      if (national.startsWith('0034')) {
        national = national.substring(4);
      } else if (national.startsWith('34')) {
        national = national.substring(2);
      }
      if (national.length > 9) national = national.substring(0, 9);
      final grouped = groupEveryThree(national);
      return grouped.isEmpty ? '+34' : '+34 $grouped';
    }

    final national =
        digits.length > 9 ? digits.substring(0, 9) : digits;
    return groupEveryThree(national);
  }

  /// Extrae los 9 dígitos nacionales o devuelve null si no es parseable.
  static String? normalize(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('0034')) {
      digits = digits.substring(4);
    } else if (digits.startsWith('34') && digits.length >= 11) {
      digits = digits.substring(2);
    }

    if (digits.length != 9) return null;
    return digits;
  }

  static bool isValid(String input) {
    final normalized = normalize(input);
    if (normalized == null) return false;
    if (_isTrivialFake(normalized)) return false;
    return _mobilePattern.hasMatch(normalized);
  }

  /// Mensaje de error para formularios, o null si es válido.
  static String? validationError(String? input) {
    if (input == null || input.trim().isEmpty) {
      return 'Teléfono obligatorio';
    }

    final normalized = normalize(input);
    if (normalized == null) {
      return 'Introduce un móvil español de 9 dígitos';
    }
    if (_isTrivialFake(normalized)) {
      return 'Número no válido';
    }
    if (!_mobilePattern.hasMatch(normalized)) {
      return 'Debe ser un móvil español (empieza por 6 o 7)';
    }
    return null;
  }

  /// Formato legible: 612 345 678
  static String format(String input) {
    final normalized = normalize(input);
    if (normalized == null) return formatAsYouType(input);
    return groupEveryThree(normalized);
  }
}