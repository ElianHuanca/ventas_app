@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/auth.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Login que no responde hasta que se complete [respuesta]: deja la
/// pantalla en "enviando" para capturar el spinner del botón.
class _AuthQueEspera extends FakeAuthRepository {
  final respuesta = Completer<void>();

  @override
  Future<void> iniciarSesion(
      {required String email, required String password}) async {
    intentos++;
    await respuesta.future;
  }
}

void main() {
  final email = find.byKey(const Key('login_email'));
  final password = find.byKey(const Key('login_password'));
  final ingresar = find.byKey(const Key('login_submit'));

  Future<void> montar(WidgetTester tester, AuthRepository repo,
          {bool asentar = true}) =>
      montarParaCaptura(
        tester,
        BlocProvider(
          create: (_) => LoginFormCubit(authRepository: repo),
          child: const LoginScreen(),
        ),
        asentar: asentar,
      );

  /// Escribe las credenciales y saca el foco (sin cursor ni borde de foco
  /// en la captura).
  Future<void> completar(WidgetTester tester, String clave) async {
    await tester.enterText(email, FakeAuthRepository.emailOk);
    await tester.enterText(password, clave);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  testWidgets('vacía: el botón Ingresar arranca deshabilitado', (tester) async {
    await montar(tester, FakeAuthRepository());

    await compararCaptura('login_screen_vacia');
  });

  testWidgets('completa: con email y contraseña se habilita Ingresar',
      (tester) async {
    await montar(tester, FakeAuthRepository());
    await completar(tester, FakeAuthRepository.passwordOk);

    expect(tester.widget<FilledButton>(ingresar).onPressed, isNotNull);
    await compararCaptura('login_screen_completa');
  });

  testWidgets('el ojo muestra la contraseña en claro', (tester) async {
    await montar(tester, FakeAuthRepository());
    await completar(tester, FakeAuthRepository.passwordOk);

    await tester.tap(find.byTooltip('Mostrar'));
    await tester.pumpAndSettle();

    expect(find.text(FakeAuthRepository.passwordOk), findsOneWidget);
    await compararCaptura('login_screen_contrasena_visible');
  });

  testWidgets('credenciales incorrectas muestran el error', (tester) async {
    await montar(tester, FakeAuthRepository());
    await completar(tester, 'incorrecta');

    await tester.tap(ingresar);
    await tester.pumpAndSettle();

    expect(find.text('Email o contraseña incorrectos'), findsOneWidget);
    await compararCaptura('login_screen_error_credenciales');
  });

  testWidgets('sin conexión muestra el aviso del repositorio', (tester) async {
    await montar(tester, FakeAuthRepository()..sinConexion = true);
    await completar(tester, FakeAuthRepository.passwordOk);

    await tester.tap(ingresar);
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsOneWidget);
    await compararCaptura('login_screen_sin_conexion');
  });

  testWidgets('enviando: campos deshabilitados y spinner en el botón',
      (tester) async {
    final repo = _AuthQueEspera();
    await montar(tester, repo);
    await completar(tester, FakeAuthRepository.passwordOk);

    await tester.tap(ingresar);
    await tester.pump();
    // En t=0 el spinner es un punto: se avanza el reloj (falso, así que la
    // captura sigue siendo determinística) hasta que se vea el arco
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await compararCaptura('login_screen_enviando');

    // Termina el login antes de desmontar (el cubit no puede emitir cerrado)
    repo.respuesta.complete();
    await tester.pumpAndSettle();
  });
}
