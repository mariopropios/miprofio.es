/// Stub: handoff entre pestañas solo en web.
class TabCoordinator {
  TabCoordinator._();

  static void start() {}

  static void stop() {}

  /// En no-web no hay otras pestañas: siempre false.
  static Future<bool> tryHandoff(String targetPath) async => false;

  static void listenHandoffs(void Function(String targetPath) onHandoff) {}

  static void stopListeningHandoffs() {}

  static void closeWindowIfPossible() {}
}
