import 'profile_share_stub.dart'
    if (dart.library.html) 'profile_share_web.dart' as impl;

/// Resultado de intentar compartir un perfil.
enum ProfileShareOutcome {
  /// Hoja nativa del sistema (WhatsApp, etc.).
  shared,

  /// Se abrió WhatsApp con el texto.
  openedWhatsApp,

  /// Se copió el enlace al portapapeles.
  copied,

  /// El usuario canceló la hoja de compartir.
  cancelled,

  /// Falló todo.
  failed,
}

/// Comparte un mensaje de perfil.
///
/// [text] debe incluir ya la URL (una sola vez). No se vuelve a añadir.
Future<ProfileShareOutcome> shareProfileLink({
  required String url,
  required String text,
  String title = 'miProfio.es',
}) {
  return impl.shareProfileLink(url: url, text: text, title: title);
}
