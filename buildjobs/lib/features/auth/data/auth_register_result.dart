/// Resultado de intentar registrar o acceder con email/contraseña.
typedef AuthRegisterResult = ({
  String? userId,
  bool needsEmailConfirmation,
  bool accountAlreadyExists,
});
