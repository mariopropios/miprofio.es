/// Sugerencias para errores frecuentes al escribir dominios de email.
abstract final class EmailTypoHelper {
  static const _domainFixes = <String, String>{
    'gmial.com': 'gmail.com',
    'gmal.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gnail.com': 'gmail.com',
    'gmail.co': 'gmail.com',
    'gmail.con': 'gmail.com',
    'gmail.cm': 'gmail.com',
    'hotmal.com': 'hotmail.com',
    'hotmial.com': 'hotmail.com',
    'outlok.com': 'outlook.com',
    'outllok.com': 'outlook.com',
    'yaho.com': 'yahoo.com',
    'yahooo.com': 'yahoo.com',
    'icloud.co': 'icloud.com',
  };

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidFormat(String email) =>
      _emailPattern.hasMatch(email.trim());

  /// Devuelve una sugerencia si el dominio parece un typo habitual.
  static String? suggestFix(String email) {
    final trimmed = email.trim();
    final parts = trimmed.split('@');
    if (parts.length != 2) return null;

    final local = parts[0];
    final domain = parts[1].toLowerCase();
    final fixedDomain = _domainFixes[domain];
    if (fixedDomain == null) return null;

    return '$local@$fixedDomain';
  }
}
