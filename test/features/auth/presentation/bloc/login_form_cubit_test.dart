import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/auth.dart';

import '../../../../helpers/fake_repositories.dart';

/// Login que no responde hasta que se complete [respuesta].
class _AuthLenta extends FakeAuthRepository {
  final respuesta = Completer<void>();

  @override
  Future<void> iniciarSesion(
      {required String email, required String password}) async {
    intentos++;
    await respuesta.future;
  }
}

/// Falla con algo que no es [AuthFallo] (p. ej. un error inesperado).
class _AuthRota extends FakeAuthRepository {
  @override
  Future<void> iniciarSesion(
      {required String email, required String password}) async {
    throw StateError('boom');
  }
}

void main() {
  void completar(LoginFormCubit cubit) => cubit
    ..onEmailChanged(FakeAuthRepository.emailOk)
    ..onPasswordChanged(FakeAuthRepository.passwordOk);

  test('mientras envía no deja reenviar (doble toque)', () async {
    final repo = _AuthLenta();
    final cubit = LoginFormCubit(authRepository: repo);
    addTearDown(cubit.close);
    completar(cubit);

    final primero = cubit.onSubmit();
    expect(cubit.state.enviando, isTrue);
    expect(cubit.state.puedeEnviar, isFalse);
    expect(await cubit.onSubmit(), isFalse);

    repo.respuesta.complete();
    expect(await primero, isTrue);
    expect(cubit.state.enviando, isFalse);
    expect(repo.intentos, 1);
  });

  test('un error inesperado muestra un mensaje genérico, no la excepción',
      () async {
    final cubit = LoginFormCubit(authRepository: _AuthRota());
    addTearDown(cubit.close);
    completar(cubit);

    expect(await cubit.onSubmit(), isFalse);
    expect(cubit.state.error, 'No se pudo iniciar sesión');
    expect(cubit.state.enviando, isFalse);
  });

  test('un email de solo espacios no habilita el envío', () {
    final cubit = LoginFormCubit(authRepository: FakeAuthRepository());
    addTearDown(cubit.close);

    cubit
      ..onEmailChanged('   ')
      ..onPasswordChanged('x');

    expect(cubit.state.puedeEnviar, isFalse);
  });

  test('la contraseña no se recorta (los espacios cuentan)', () async {
    final repo = FakeAuthRepository();
    final cubit = LoginFormCubit(authRepository: repo);
    addTearDown(cubit.close);

    cubit
      ..onEmailChanged(FakeAuthRepository.emailOk)
      ..onPasswordChanged(' ${FakeAuthRepository.passwordOk} ');

    expect(await cubit.onSubmit(), isFalse);
    expect(repo.haySesion, isFalse);
  });
}
