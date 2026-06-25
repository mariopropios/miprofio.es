import 'package:flutter/services.dart';

import 'spanish_phone_validator.dart';

/// Formatea un móvil español agrupando dígitos de 3 en 3 mientras se escribe.
class SpanishPhoneInputFormatter extends TextInputFormatter {
  const SpanishPhoneInputFormatter();
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = SpanishPhoneValidator.formatAsYouType(newValue.text);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
