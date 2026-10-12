import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

void main() {
  final email = find.byKey(const Key('login_email'));
  final password = find.byKey(const Key('login_password'));
  final ingresar = find.byKey(const Key('login_submit'));

  Future<void> montar(WidgetTester tester, AuthRepository repo) async {
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider(
        create: (_) => LoginFormCubit(authRepository: repo),
        child: const LoginScreen(),
      ),
    ));
  }

  TextField campo(WidgetTester tester, Finder finder) =>
      tester.widget<TextField>(finder);

  testWidgets('la contraseña arranca oculta y el ojo la muestra y la oculta',
      (tester) async {
    await montar(tester, FakeAuthRepository());
    expect(campo(tester, password).obscureText, isTrue);

    await tester.tap(find.byTooltip('Mostrar'));
    await tester.pump();
    expect(campo(tester, password).obscureText, isFalse);
    expect(find.byTooltip('Ocultar'), findsOneWidget);

    await tester.tap(find.byTooltip('Ocultar'));
    await tester.pump();
    expect(campo(tester, password).obscureText, isTrue);
  });

  testWidgets('"Listo" en el teclado de la contraseña envía el formulario',
      (tester) async {
    final repo = FakeAuthRepository();
    await montar(tester, repo);
    await tester.enterText(email, FakeAuthRepository.emailOk);
    await tester.enterText(password, FakeAuthRepository.passwordOk);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repo.intentos, 1);
    expect(repo.haySesion, isTrue);
  });

  testWidgets(
      'mientras inicia sesión bloquea los campos y el botón y muestra el '
      'progreso', (tester) async {
    final repo = _AuthLenta();
    await montar(tester, repo);
    await tester.enterText(email, FakeAuthRepository.emailOk);
    await tester.enterText(password, FakeAuthRepository.passwordOk);
    await tester.pump();

    await tester.tap(ingresar);
    await tester.pump();

    expect(campo(tester, email).enabled, isFalse);
    expect(campo(tester, password).enabled, isFalse);
    expect(tester.widget<FilledButton>(ingresar).onPressed, isNull);
    expect(
        find.descendant(
            of: ingresar, matching: find.byType(CircularProgressIndicator)),
        findsOneWidget);
    expect(find.text('Ingresar'), findsNothing);

    // Un segundo toque no dispara otro intento
    await tester.tap(ingresar, warnIfMissed: false);
    await tester.pump();
    expect(repo.intentos, 1);

    repo.respuesta.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ingresar'), findsOneWidget);
    expect(campo(tester, email).enabled, isTrue);
  });

  testWidgets('sin conexión muestra el mensaje y deja reintentar',
      (tester) async {
    final repo = FakeAuthRepository()..sinConexion = true;
    await montar(tester, repo);
    await tester.enterText(email, FakeAuthRepository.emailOk);
    await tester.enterText(password, FakeAuthRepository.passwordOk);
    await tester.pump();

    await tester.tap(ingresar);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_error')), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);

    repo.sinConexion = false;
    await tester.tap(ingresar);
    await tester.pumpAndSettle();
    expect(repo.haySesion, isTrue);
    expect(find.byKey(const Key('login_error')), findsNothing);
  });

  testWidgets('tocar fuera de los campos cierra el teclado', (tester) async {
    await montar(tester, FakeAuthRepository());
    await tester.tap(email);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Huantex'));
    await tester.pump();

    expect(tester.testTextInput.isVisible, isFalse);
    expect(FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()));
  });
}
