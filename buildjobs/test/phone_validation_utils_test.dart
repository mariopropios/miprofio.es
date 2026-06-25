import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_field/phone_number.dart';

import 'package:buildjobs/core/utils/phone_validation_utils.dart';

void main() {
  group('PhoneValidationUtils', () {
    test('formatea España según estándar nacional', () {
      expect(
        PhoneValidationUtils.formatAsYouType('ES', '612345678'),
        '612 34 56 78',
      );
    });

    test('valida móvil español de 9 dígitos', () {
      final phone = PhoneNumber(
        countryISOCode: 'ES',
        countryCode: '+34',
        number: '612345678',
      );
      expect(PhoneValidationUtils.isValid(phone), isTrue);
      expect(PhoneValidationUtils.toE164(phone), '+34612345678');
    });

    test('rechaza número corto para España', () {
      final phone = PhoneNumber(
        countryISOCode: 'ES',
        countryCode: '+34',
        number: '61234',
      );
      expect(PhoneValidationUtils.validate(phone),
          PhoneValidationUtils.invalidCountryMessage);
    });

    test('formatea número US con paréntesis', () {
      final formatted =
          PhoneValidationUtils.formatAsYouType('US', '2025550123');
      expect(formatted.contains('(') || formatted.contains('-'), isTrue);
    });

    test('hintForCountry muestra ejemplo formateado por país', () {
      expect(
        PhoneValidationUtils.hintForCountry('ES', 9),
        '612 34 56 78',
      );
      expect(
        PhoneValidationUtils.hintForCountry('US', 10),
        contains('202'),
      );
      expect(
        PhoneValidationUtils.hintForCountry('FR', 9),
        isNotEmpty,
      );
    });

    test('PhoneAsYouTypeFormatter no permite más dígitos que el máximo del país',
        () {
      final formatter = PhoneAsYouTypeFormatter('ES', maxDigits: 9);
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '6123456789123'),
      );
      expect(PhoneValidationUtils.digitsOnly(result.text), '612345678');
      expect(result.text, '612 34 56 78');
    });

    test('PhoneAsYouTypeFormatter separa dígitos mientras se escribe', () {
      final formatter = PhoneAsYouTypeFormatter('ES', maxDigits: 9);
      var value = const TextEditingValue(text: '');

      for (final digit in '612345678'.split('')) {
        final rawNext = TextEditingValue(
          text: value.text + digit,
          selection: TextSelection.collapsed(offset: value.text.length + 1),
        );
        value = formatter.formatEditUpdate(value, rawNext);
        // Simula re-aplicación tras rebuild del padre.
        value = formatter.formatEditUpdate(value, value);
      }

      expect(value.text, '612 34 56 78');
    });
  });
}
