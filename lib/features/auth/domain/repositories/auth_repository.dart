/// Sesión del usuario (Supabase Auth). Las cuentas las crea el dueño desde
/// el dashboard de Supabase: la app no permite registrarse.
abstract class AuthRepository {
  /// `true` si hay una sesión guardada en el dispositivo.
  bool get haySesion;

  /// Email del usuario logueado, o null.
  String? get email;

  /// Emite cada vez que se inicia o se cierra sesión (incluye la expiración).
  Stream<bool> get cambiosDeSesion;

  /// Lanza [AuthFallo] con un mensaje para mostrar si no se pudo entrar.
  Future<void> iniciarSesion({required String email, required String password});

  Future<void> cerrarSesion();
}

/// Error de login con un mensaje en español listo para la UI.
class AuthFallo implements Exception {
  final String mensaje;
  const AuthFallo(this.mensaje);

  @override
  String toString() => mensaje;
}
