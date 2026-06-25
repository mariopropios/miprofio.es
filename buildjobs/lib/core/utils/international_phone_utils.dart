import '../constants/phone_countries.dart';

class InternationalPhoneUtils {
  InternationalPhoneUtils._();

  static String digitsOnly(String input) =>
      input.replaceAll(RegExp(r'\D'), '');

  /// Agrupa dígitos nacionales de 3 en 3.
  static String formatNational(String input) {
    final digits = digitsOnly(input);
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Número completo internacional: +34 612 345 678
  static String fullNumber(PhoneCountry country, String nationalInput) {
    final national = formatNational(nationalInput);
    if (national.isEmpty) return country.dialLabel;
    return '${country.dialLabel} $national';
  }

  static bool isValid(PhoneCountry country, String nationalInput) {
    return validationError(country, nationalInput) == null;
  }

  static String? validationError(PhoneCountry country, String? nationalInput) {
    final digits = digitsOnly(nationalInput ?? '');
    if (digits.isEmpty) return 'Teléfono obligatorio';
    if (digits.length < 6) return 'Número demasiado corto';
    if (digits.length > 14) return 'Número demasiado largo';
    return null;
  }
}
