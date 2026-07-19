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
        PushSetupState.needsHomeScreenInstall => 'Notificaciones no disponibles',
        PushSetupState.needsPermission => 'Activa las notificaciones',
        PushSetupState.permissionDenied => 'Permiso bloqueado',
        PushSetupState.tokenSyncFailed => 'Dispositivo no registrado',
        PushSetupState.ready => 'Notificaciones activas',
      };

  String get description => switch (this) {
        PushSetupState.firebaseMissing =>
          'El servicio de avisos no está disponible en este entorno.',
        PushSetupState.privateBrowsing =>
          'En iPhone, las notificaciones no funcionan en Safari en modo privado. '
          'Abre miProfio en una ventana normal de Safari.',
        PushSetupState.needsHomeScreenInstall =>
          'En este navegador de iPhone las notificaciones push no están disponibles. '
          'Puedes seguir usando avisos por email.',
        PushSetupState.needsPermission =>
          'Recibe un aviso cuando alguien te escriba, aunque no tengas la app abierta.',
        PushSetupState.permissionDenied =>
          'Antes denegaste las notificaciones. Ve a Ajustes → Safari / sitio → '
          'Notificaciones y actívalas.',
        PushSetupState.tokenSyncFailed =>
          'Concediste permiso pero no se pudo registrar el dispositivo. '
          'Prueba de nuevo o usa avisos por email.',
        PushSetupState.ready =>
          'Recibirás avisos cuando te envíen mensajes nuevos.',
      };

  bool get showActivateButton =>
      this == PushSetupState.needsPermission ||
      this == PushSetupState.tokenSyncFailed;

  bool get isBlocking => this != PushSetupState.ready;
}
