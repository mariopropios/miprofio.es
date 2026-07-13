/// Estado de configuración de notificaciones push (web/PWA).
enum PushSetupState {
  /// Firebase no inicializado (.env).
  firebaseMissing,

  /// Safari modo privado / ventana privada: push no soportado.
  privateBrowsing,

  /// iPhone: hay que añadir la app al inicio (PWA).
  needsHomeScreenInstall,

  /// Falta conceder permiso de notificaciones.
  needsPermission,

  /// Usuario denegó permiso; hay que ir a Ajustes del sistema.
  permissionDenied,

  /// Permiso OK pero el token no llegó al servidor (modo privado, sin PWA, etc.).
  tokenSyncFailed,

  /// Permiso OK y token sincronizado.
  ready,
}

extension PushSetupStateX on PushSetupState {
  String get title => switch (this) {
        PushSetupState.firebaseMissing => 'Notificaciones no configuradas',
        PushSetupState.privateBrowsing => 'Modo privado detectado',
        PushSetupState.needsHomeScreenInstall => 'Añade la app al inicio',
        PushSetupState.needsPermission => 'Activa las notificaciones',
        PushSetupState.permissionDenied => 'Permiso bloqueado',
        PushSetupState.tokenSyncFailed => 'Dispositivo no registrado',
        PushSetupState.ready => 'Notificaciones activas',
      };

  String get description => switch (this) {
        PushSetupState.firebaseMissing =>
          'El servicio de avisos no está disponible en este entorno.',
        PushSetupState.privateBrowsing =>
          'En iPhone, las notificaciones NO funcionan en Safari en modo privado. '
          'Cierra la ventana privada, abre miprofio.es en modo normal, añádela a la '
          'pantalla de inicio y ábrela desde el icono.',
        PushSetupState.needsHomeScreenInstall =>
          'En iPhone debes abrir miProfio desde el icono de inicio (no desde Safari). '
          'Safari → Compartir → «Añadir a pantalla de inicio».',
        PushSetupState.needsPermission =>
          'Recibe un aviso cuando alguien te escriba, aunque no tengas la app abierta.',
        PushSetupState.permissionDenied =>
          'Antes denegaste las notificaciones. Ve a Ajustes → miProfio.es → '
          'Notificaciones y actívalas.',
        PushSetupState.tokenSyncFailed =>
          'Concediste permiso pero el iPhone no pudo registrar el dispositivo. '
          'Cierra el modo privado, abre miProfio desde el icono del inicio y vuelve a pulsar Activar.',
        PushSetupState.ready =>
          'Recibirás avisos cuando te envíen mensajes nuevos.',
      };

  bool get showActivateButton =>
      this == PushSetupState.needsPermission ||
      this == PushSetupState.needsHomeScreenInstall ||
      this == PushSetupState.tokenSyncFailed;

  bool get isBlocking => this != PushSetupState.ready;
}
