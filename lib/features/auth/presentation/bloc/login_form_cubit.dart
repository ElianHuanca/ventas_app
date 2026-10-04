import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/auth/domain/repositories/auth_repository.dart';

class LoginFormState {
  final String email;
  final String password;
  final bool enviando;
  final String? error;

  const LoginFormState({
    this.email = '',
    this.password = '',
    this.enviando = false,
    this.error,
  });

  bool get puedeEnviar =>
      !enviando && email.trim().isNotEmpty && password.isNotEmpty;

  // `error` se pasa siempre: cualquier cambio limpia el error anterior
  LoginFormState copyWith({
    String? email,
    String? password,
    bool? enviando,
    String? error,
  }) =>
      LoginFormState(
        email: email ?? this.email,
        password: password ?? this.password,
        enviando: enviando ?? this.enviando,
        error: error,
      );
}

class LoginFormCubit extends Cubit<LoginFormState> {
  final AuthRepository authRepository;

  LoginFormCubit({required this.authRepository}) : super(const LoginFormState());

  void onEmailChanged(String value) => emit(state.copyWith(email: value));
  void onPasswordChanged(String value) => emit(state.copyWith(password: value));

  /// Devuelve `true` si entró. La navegación la hace el router al detectar
  /// la sesión nueva.
  Future<bool> onSubmit() async {
    if (!state.puedeEnviar) return false;
    emit(state.copyWith(enviando: true));
    try {
      await authRepository.iniciarSesion(
        email: state.email.trim(),
        password: state.password,
      );
      emit(state.copyWith(enviando: false));
      return true;
    } on AuthFallo catch (e) {
      emit(state.copyWith(enviando: false, error: e.mensaje));
      return false;
    } catch (_) {
      emit(state.copyWith(enviando: false, error: 'No se pudo iniciar sesión'));
      return false;
    }
  }
}
