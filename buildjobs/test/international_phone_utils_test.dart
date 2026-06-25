import 'package:flutter_test/flutter_test.dart';

import 'package:buildjobs/core/constants/phone_countries.dart';
import 'package:buildjobs/core/utils/international_phone_utils.dart';

void main() {
  group('InternationalPhoneUtils', () {
    test('formatea número nacional de 3 en 3', () {
      expect(InternationalPhoneUtils.formatNational('612345678'), '612 345 678');
    });

    test('combina prefijo y número', () {
      expect(
        InternationalPhoneUtils.fullNumber(PhoneCountries.spain, '612345678'),
        '+34 612 345 678',
      );
    });

    test('acepta números internacionales válidos', () {
      expect(
        InternationalPhoneUtils.isValid(
          PhoneCountries.findByIso('FR')!,
          '612345678',
        ),
        isTrue,
      );
    });

    test('rechaza números demasiado cortos', () {
      expect(
        InternationalPhoneUtils.isValid(PhoneCountries.spain, '12345'),
        isFalse,
      );
    });
  });
}
