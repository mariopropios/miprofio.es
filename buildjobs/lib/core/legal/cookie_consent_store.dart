import 'cookie_consent_store_stub.dart'
    if (dart.library.html) 'cookie_consent_store_web.dart' as impl;

/// Preferencias de consentimiento de cookies / tecnologías similares.
class CookieConsentPrefs {
  const CookieConsentPrefs({
    required this.decided,
    required this.analytics,
    required this.marketing,
  });

  /// true si el usuario ya eligió (aceptar / rechazar / guardar).
  final bool decided;

  /// Métricas opcionales (hoy no hay analytics cargado).
  final bool analytics;

  /// Marketing opcional (hoy no hay cookies publicitarias).
  final bool marketing;

  static const undecided = CookieConsentPrefs(
    decided: false,
    analytics: false,
    marketing: false,
  );

  static const rejectedOptional = CookieConsentPrefs(
    decided: true,
    analytics: false,
    marketing: false,
  );

  static const acceptedAll = CookieConsentPrefs(
    decided: true,
    analytics: true,
    marketing: true,
  );

  CookieConsentPrefs copyWith({
    bool? decided,
    bool? analytics,
    bool? marketing,
  }) {
    return CookieConsentPrefs(
      decided: decided ?? this.decided,
      analytics: analytics ?? this.analytics,
      marketing: marketing ?? this.marketing,
    );
  }
}

abstract final class CookieConsentStore {
  CookieConsentStore._();

  static CookieConsentPrefs read() => impl.readConsent();

  static Future<void> write(CookieConsentPrefs prefs) =>
      impl.writeConsent(prefs);
}
