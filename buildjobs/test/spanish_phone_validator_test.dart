import 'package:flutter_test/flutter_test.dart';

import 'package:buildjobs/core/utils/spanish_phone_validator.dart';

void main() {
  group('SpanishPhoneValidator', () {
    test('acepta móviles nacionales 6xx y 7xx', () {
      expect(SpanishPhoneValidator.isValid('612345678'), isTrue);
      expect(SpanishPhoneValidator.isValid('712345678'), isTrue);
      expect(SpanishPhoneValidator.isValid('612 34 56 78'), isTrue);
    });

    test('acepta prefijo internacional +34', () {
      expect(SpanishPhoneValidator.isValid('+34 612 345 678'), isTrue);
      expect(SpanishPhoneValidator.isValid('0034612345678'), isTrue);
    });

    test('rechaza fijos, cortos y secuencias obvias', () {
      expect(SpanishPhoneValidator.isValid('912345678'), isFalse);
      expect(SpanishPhoneValidator.isValid('812345678'), isFalse);
      expect(SpanishPhoneValidator.isValid('123456789'), isFalse);
      expect(SpanishPhoneValidator.isValid('61234567'), isFalse);
      expect(SpanishPhoneValidator.isValid('666666666'), isFalse);
      expect(SpanishPhoneValidator.isValid('600000000'), isFalse);
    });

    test('formatea a grupos de 3', () {
      expect(SpanishPhoneValidator.format('612345678'), '612 345 678');
      expect(SpanishPhoneValidator.formatAsYouType('612345'), '612 345');
      expect(
        SpanishPhoneValidator.formatAsYouType('+34612345678'),
        '+34 612 345 678',
      );
    });
  });
}
