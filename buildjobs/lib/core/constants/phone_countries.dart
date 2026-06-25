/// País con prefijo telefónico internacional.
class PhoneCountry {
  const PhoneCountry({
    required this.isoCode,
    required this.name,
    required this.dialCode,
  });

  final String isoCode;
  final String name;
  final String dialCode;

  String get flag => PhoneCountries.flagEmoji(isoCode);

  String get dialLabel => '+$dialCode';
}

class PhoneCountries {
  PhoneCountries._();

  static const spain = PhoneCountry(
    isoCode: 'ES',
    name: 'España',
    dialCode: '34',
  );

  static const defaultCountry = spain;

  static const all = <PhoneCountry>[
    spain,
    PhoneCountry(isoCode: 'PT', name: 'Portugal', dialCode: '351'),
    PhoneCountry(isoCode: 'FR', name: 'Francia', dialCode: '33'),
    PhoneCountry(isoCode: 'IT', name: 'Italia', dialCode: '39'),
    PhoneCountry(isoCode: 'DE', name: 'Alemania', dialCode: '49'),
    PhoneCountry(isoCode: 'GB', name: 'Reino Unido', dialCode: '44'),
    PhoneCountry(isoCode: 'IE', name: 'Irlanda', dialCode: '353'),
    PhoneCountry(isoCode: 'BE', name: 'Bélgica', dialCode: '32'),
    PhoneCountry(isoCode: 'NL', name: 'Países Bajos', dialCode: '31'),
    PhoneCountry(isoCode: 'CH', name: 'Suiza', dialCode: '41'),
    PhoneCountry(isoCode: 'AT', name: 'Austria', dialCode: '43'),
    PhoneCountry(isoCode: 'SE', name: 'Suecia', dialCode: '46'),
    PhoneCountry(isoCode: 'NO', name: 'Noruega', dialCode: '47'),
    PhoneCountry(isoCode: 'DK', name: 'Dinamarca', dialCode: '45'),
    PhoneCountry(isoCode: 'PL', name: 'Polonia', dialCode: '48'),
    PhoneCountry(isoCode: 'RO', name: 'Rumanía', dialCode: '40'),
    PhoneCountry(isoCode: 'UA', name: 'Ucrania', dialCode: '380'),
    PhoneCountry(isoCode: 'RU', name: 'Rusia', dialCode: '7'),
    PhoneCountry(isoCode: 'US', name: 'Estados Unidos', dialCode: '1'),
    PhoneCountry(isoCode: 'CA', name: 'Canadá', dialCode: '1'),
    PhoneCountry(isoCode: 'MX', name: 'México', dialCode: '52'),
    PhoneCountry(isoCode: 'AR', name: 'Argentina', dialCode: '54'),
    PhoneCountry(isoCode: 'CO', name: 'Colombia', dialCode: '57'),
    PhoneCountry(isoCode: 'CL', name: 'Chile', dialCode: '56'),
    PhoneCountry(isoCode: 'PE', name: 'Perú', dialCode: '51'),
    PhoneCountry(isoCode: 'EC', name: 'Ecuador', dialCode: '593'),
    PhoneCountry(isoCode: 'VE', name: 'Venezuela', dialCode: '58'),
    PhoneCountry(isoCode: 'BR', name: 'Brasil', dialCode: '55'),
    PhoneCountry(isoCode: 'UY', name: 'Uruguay', dialCode: '598'),
    PhoneCountry(isoCode: 'PY', name: 'Paraguay', dialCode: '595'),
    PhoneCountry(isoCode: 'BO', name: 'Bolivia', dialCode: '591'),
    PhoneCountry(isoCode: 'CR', name: 'Costa Rica', dialCode: '506'),
    PhoneCountry(isoCode: 'PA', name: 'Panamá', dialCode: '507'),
    PhoneCountry(isoCode: 'DO', name: 'Rep. Dominicana', dialCode: '1'),
    PhoneCountry(isoCode: 'CU', name: 'Cuba', dialCode: '53'),
    PhoneCountry(isoCode: 'MA', name: 'Marruecos', dialCode: '212'),
    PhoneCountry(isoCode: 'DZ', name: 'Argelia', dialCode: '213'),
    PhoneCountry(isoCode: 'TN', name: 'Túnez', dialCode: '216'),
    PhoneCountry(isoCode: 'EG', name: 'Egipto', dialCode: '20'),
    PhoneCountry(isoCode: 'SN', name: 'Senegal', dialCode: '221'),
    PhoneCountry(isoCode: 'NG', name: 'Nigeria', dialCode: '234'),
    PhoneCountry(isoCode: 'CN', name: 'China', dialCode: '86'),
    PhoneCountry(isoCode: 'IN', name: 'India', dialCode: '91'),
    PhoneCountry(isoCode: 'JP', name: 'Japón', dialCode: '81'),
    PhoneCountry(isoCode: 'KR', name: 'Corea del Sur', dialCode: '82'),
    PhoneCountry(isoCode: 'AU', name: 'Australia', dialCode: '61'),
    PhoneCountry(isoCode: 'NZ', name: 'Nueva Zelanda', dialCode: '64'),
    PhoneCountry(isoCode: 'TR', name: 'Turquía', dialCode: '90'),
    PhoneCountry(isoCode: 'GR', name: 'Grecia', dialCode: '30'),
    PhoneCountry(isoCode: 'CZ', name: 'Rep. Checa', dialCode: '420'),
    PhoneCountry(isoCode: 'HU', name: 'Hungría', dialCode: '36'),
    PhoneCountry(isoCode: 'BG', name: 'Bulgaria', dialCode: '359'),
    PhoneCountry(isoCode: 'HR', name: 'Croacia', dialCode: '385'),
    PhoneCountry(isoCode: 'RS', name: 'Serbia', dialCode: '381'),
    PhoneCountry(isoCode: 'AD', name: 'Andorra', dialCode: '376'),
    PhoneCountry(isoCode: 'LU', name: 'Luxemburgo', dialCode: '352'),
  ];

  static PhoneCountry? findByIso(String iso) {
    for (final c in all) {
      if (c.isoCode == iso.toUpperCase()) return c;
    }
    return null;
  }

  static String flagEmoji(String countryCode) {
    return countryCode.toUpperCase().replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => String.fromCharCode(
            match.group(0)!.codeUnitAt(0) + 127397,
          ),
        );
  }
}
