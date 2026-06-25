import 'package:flutter/services.dart';
import 'package:intl_phone_field/phone_number.dart' as intl_field;
import 'package:phone_numbers_parser/phone_numbers_parser.dart' as pnp;

/// Validación y formato internacional basado en libphonenumber (phone_numbers_parser).
class PhoneValidationUtils {
  PhoneValidationUtils._();

  static const invalidCountryMessage =
      'Número de teléfono inválido para este país';

  static pnp.IsoCode? isoFromCountryCode(String? isoCode) {
    if (isoCode == null || isoCode.isEmpty) return null;
    for (final iso in pnp.IsoCode.values) {
      if (iso.name == isoCode.toUpperCase()) return iso;
    }
    return null;
  }

  static String digitsOnly(String input) =>
      input.replaceAll(RegExp(r'\D'), '');

  /// Ejemplo nacional formateado para el placeholder del campo.
  static String hintForCountry(String isoCode, int maxLength) {
    var digits = _exampleDigitsByIso[isoCode] ?? _generateFallbackDigits(maxLength);
    if (digits.length > maxLength) {
      digits = digits.substring(0, maxLength);
    } else if (digits.length < maxLength) {
      digits = _padDigits(digits, maxLength);
    }

    final formatted = formatAsYouType(isoCode, digits);
    if (formatted == digits && digits.length > 3) {
      return _groupDigitsSimply(digits);
    }
    return formatted;
  }

  static const _exampleDigitsByIso = {
    'AD': '312345',
    'AE': '501234567',
    'AR': '1123456789',
    'AT': '664123456',
    'AU': '412345678',
    'BE': '470123456',
    'BO': '71234567',
    'BR': '11987654321',
    'CA': '2045550123',
    'CH': '781234567',
    'CL': '912345678',
    'CN': '13123456789',
    'CO': '3211234567',
    'CR': '83123456',
    'CU': '51234567',
    'CZ': '601123456',
    'DE': '1512345678',
    'DK': '20123456',
    'DO': '8095551234',
    'EC': '991234567',
    'EG': '1012345678',
    'ES': '612345678',
    'FI': '412345678',
    'FR': '612345678',
    'GB': '7400123456',
    'GR': '6912345678',
    'GT': '51234567',
    'HN': '91234567',
    'HR': '912345678',
    'HU': '201234567',
    'IE': '851234567',
    'IL': '501234567',
    'IN': '9876543210',
    'IT': '3123456789',
    'JP': '9012345678',
    'KR': '1012345678',
    'MA': '612345678',
    'MX': '5512345678',
    'NG': '8021234567',
    'NL': '612345678',
    'NO': '40612345',
    'NZ': '211234567',
    'PA': '61234567',
    'PE': '912345678',
    'PL': '512345678',
    'PT': '912345678',
    'PY': '961234567',
    'RO': '712345678',
    'RU': '9123456789',
    'SA': '512345678',
    'SE': '701234567',
    'SV': '70123456',
    'TR': '5012345678',
    'UA': '501234567',
    'US': '2025550123',
    'UY': '94231234',
    'VE': '4121234567',
    'ZA': '821234567',
  };

  static String _generateFallbackDigits(int maxLength) {
    const pattern = '6123456789';
    return List.generate(
      maxLength,
      (i) => pattern[i % pattern.length],
    ).join();
  }

  static String _padDigits(String digits, int maxLength) {
    const pattern = '1234567890';
    final buffer = StringBuffer(digits);
    var i = 0;
    while (buffer.length < maxLength) {
      buffer.write(pattern[i % pattern.length]);
      i++;
    }
    return buffer.toString();
  }

  static String _groupDigitsSimply(String digits) {
    final parts = <String>[];
    for (var i = 0; i < digits.length; i += 3) {
      parts.add(digits.substring(i, (i + 3).clamp(0, digits.length)));
    }
    return parts.join(' ');
  }

  /// Formato visual nacional según el estándar del país (AsYouType).
  static String formatAsYouType(String isoCode, String rawInput) {
    final iso = isoFromCountryCode(isoCode);
    if (iso == null) return rawInput;
    final digits = digitsOnly(rawInput);
    if (digits.isEmpty) return '';
    return pnp.PhoneNumberFormatter.formatNsn(digits, iso);
  }

  /// E.164 compacto: +34612345678
  static String toE164(intl_field.PhoneNumber phone) {
    final iso = isoFromCountryCode(phone.countryISOCode);
    if (iso == null) return '';
    final digits = digitsOnly(phone.number);
    if (digits.isEmpty) return '';

    try {
      final parsed = pnp.PhoneNumber.parse(
        digits,
        destinationCountry: iso,
      );
      return parsed.international.replaceAll(RegExp(r'[\s\-().]'), '');
    } catch (_) {
      final code = phone.countryCode.startsWith('+')
          ? phone.countryCode
          : '+${phone.countryCode}';
      return '$code$digits';
    }
  }

  /// Número legible: +34 612 345 678
  static String toDisplaySimple(intl_field.PhoneNumber phone) {
    final iso = isoFromCountryCode(phone.countryISOCode);
    if (iso == null) return phone.completeNumber;
    final digits = digitsOnly(phone.number);
    if (digits.isEmpty) return phone.countryCode;
    final national = pnp.PhoneNumberFormatter.formatNsn(digits, iso);
    final prefix = phone.countryCode.startsWith('+')
        ? phone.countryCode
        : '+${phone.countryCode}';
    return '$prefix $national';
  }

  static bool isValid(intl_field.PhoneNumber? phone) =>
      validate(phone) == null;

  /// Validación estricta: longitud exacta del país + patrón real.
  static String? validate(intl_field.PhoneNumber? phone) {
    if (phone == null) return 'Teléfono obligatorio';

    final digits = digitsOnly(phone.number);
    if (digits.isEmpty) return 'Teléfono obligatorio';

    final iso = isoFromCountryCode(phone.countryISOCode);
    if (iso == null) return invalidCountryMessage;

    try {
      final parsed = pnp.PhoneNumber.parse(
        digits,
        destinationCountry: iso,
      );

      final valid = parsed.isValid(type: pnp.PhoneNumberType.mobile) ||
          parsed.isValid(type: pnp.PhoneNumberType.fixedLine) ||
          parsed.isValid();

      return valid ? null : invalidCountryMessage;
    } catch (_) {
      return invalidCountryMessage;
    }
  }
}

/// Formateador dinámico AsYouType por país, con tope de dígitos nacionales.
class PhoneAsYouTypeFormatter extends TextInputFormatter {
  PhoneAsYouTypeFormatter(this.isoCode, {this.maxDigits});

  String isoCode;
  int? maxDigits;

  void updateCountry(String newIsoCode, {int? maxDigits}) {
    isoCode = newIsoCode;
    this.maxDigits = maxDigits;
  }

  static int _countDigitsBefore(String text, int offset) {
    var count = 0;
    for (var i = 0; i < offset && i < text.length; i++) {
      if (RegExp(r'\d').hasMatch(text[i])) count++;
    }
    return count;
  }

  static int _offsetAfterDigits(String formatted, int digitCount) {
    if (digitCount <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        seen++;
        if (seen >= digitCount) return i + 1;
      }
    }
    return formatted.length;
  }

  String _truncateDigits(String digits) {
    if (maxDigits != null && digits.length > maxDigits!) {
      return digits.substring(0, maxDigits!);
    }
    return digits;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits =
        _truncateDigits(PhoneValidationUtils.digitsOnly(newValue.text));

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = PhoneValidationUtils.formatAsYouType(isoCode, digits);
    final digitsBeforeCursor =
        _countDigitsBefore(newValue.text, newValue.selection.end);
    final cursorOffset = _offsetAfterDigits(
      formatted,
      digitsBeforeCursor.clamp(0, digits.length),
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
}
