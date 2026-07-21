/// Stub: sincronización multi-pestaña solo en web.
class EmailConfirmSync {
  EmailConfirmSync._();

  static const storageKey = 'profio_email_confirmed_v1';

  static void notifyConfirmed({String? userId, String? dest}) {}

  static void listen(void Function(EmailConfirmSignal signal) onSignal) {}

  static void stopListening() {}

  static EmailConfirmSignal? readLatest() => null;

  static void clear() {}
}

class EmailConfirmSignal {
  const EmailConfirmSignal({
    required this.atMs,
    this.userId,
    this.dest,
  });

  final int atMs;
  final String? userId;
  final String? dest;
}
