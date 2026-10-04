import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:textiles_app/config/supabase/supabase_config.dart';
import 'package:textiles_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  GoTrueClient get _auth => SupabaseConfig.client.auth;

  @override
  bool get haySesion => _auth.currentSession != null;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  Stream<bool> get cambiosDeSesion =>
      _auth.onAuthStateChange.map((data) => data.session != null);

  @override
  Future<void> iniciarSesion(
      {required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw AuthFallo(mensajeDeError(e.message));
    } catch (_) {
      throw const AuthFallo('Sin conexión. Revisa el internet e intenta de nuevo.');
    }
  }

  @override
  Future<void> cerrarSesion() => _auth.signOut();

  /// Traduce los mensajes de Supabase Auth a algo entendible.
  static String mensajeDeError(String mensaje) {
    final m = mensaje.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'Email o contraseña incorrectos';
    }
    if (m.contains('email not confirmed')) {
      return 'El email de esta cuenta no está confirmado';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Demasiados intentos. Espera un momento.';
    }
    return 'No se pudo iniciar sesión';
  }
}
