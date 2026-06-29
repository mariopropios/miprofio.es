/// El usuario intentó abrir un chat con su propio perfil profesional.
class ChatSelfMessageException implements Exception {
  const ChatSelfMessageException();

  @override
  String toString() => 'No puedes enviarte mensajes a ti mismo.';
}

bool isSelfMessageError(Object error) =>
    error is ChatSelfMessageException ||
    error.toString().contains('No puedes enviarte mensajes a ti mismo');

String friendlyChatErrorMessage(Object error) {
  if (error is ChatSelfMessageException) {
    return error.toString();
  }
  final raw = error.toString();
  if (raw.startsWith('Exception: ')) {
    return raw.substring('Exception: '.length);
  }
  return raw;
}
