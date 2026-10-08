import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/auth.dart';

import '../../helpers/fake_repositories.dart';

void main() {
  group('redireccionPorSesion', () {
    test('sin sesión cualquier ruta va a /login', () {
      expect(redireccionPorSesion(haySesion: false, ubicacion: '/'), '/login');
      expect(
          redireccionPorSesion(haySesion: false, ubicacion: '/dashboard'),
          '/login');
    });

    test('sin sesión en /login se queda', () {
      expect(redireccionPorSesion(haySesion: false, ubicacion: '/login'),
          isNull);
    });

    test('con sesión /login vuelve al inicio y el resto pasa', () {
      expect(redireccionPorSesion(haySesion: true, ubicacion: '/login'), '/');
      expect(redireccionPorSesion(haySesion: true, ubicacion: '/telas'),
          isNull);
    });
  });

  group('AuthRepositoryImpl.mensajeDeError', () {
    test('traduce los mensajes conocidos de Supabase', () {
      expect(AuthRepositoryImpl.mensajeDeError('Invalid login credentials'),
          'Email o contraseña incorrectos');
      expect(AuthRepositoryImpl.mensajeDeError('Email not confirmed'),
          'El email de esta cuenta no está confirmado');
      expect(
          AuthRepositoryImpl.mensajeDeError(
              'For security purposes, too many requests'),
          'Demasiados intentos. Espera un momento.');
    });

    test('mensaje genérico para lo desconocido', () {
      expect(AuthRepositoryImpl.mensajeDeError('boom'),
          'No se pudo iniciar sesión');
    });
  });

  group('LoginFormCubit', () {
    late FakeAuthRepository repo;
    late LoginFormCubit cubit;

    setUp(() {
      repo = FakeAuthRepository();
      cubit = LoginFormCubit(authRepository: repo);
    });
    tearDown(() => cubit.close());

    test('no envía con campos vacíos', () async {
      expect(cubit.state.puedeEnviar, isFalse);
      expect(await cubit.onSubmit(), isFalse);
      expect(repo.intentos, 0);
    });

    test('credenciales correctas inician sesión (email sin espacios)',
        () async {
      cubit
        ..onEmailChanged('  ${FakeAuthRepository.emailOk} ')
        ..onPasswordChanged(FakeAuthRepository.passwordOk);

      expect(await cubit.onSubmit(), isTrue);
      expect(repo.haySesion, isTrue);
      expect(cubit.state.enviando, isFalse);
      expect(cubit.state.error, isNull);
    });

    test('credenciales incorrectas muestran el error y escribir lo limpia',
        () async {
      cubit
        ..onEmailChanged(FakeAuthRepository.emailOk)
        ..onPasswordChanged('mala');

      expect(await cubit.onSubmit(), isFalse);
      expect(repo.haySesion, isFalse);
      expect(cubit.state.error, 'Email o contraseña incorrectos');

      cubit.onPasswordChanged('mala2');
      expect(cubit.state.error, isNull);
    });

    test('sin conexión devuelve el mensaje del repositorio', () async {
      repo.sinConexion = true;
      cubit
        ..onEmailChanged(FakeAuthRepository.emailOk)
        ..onPasswordChanged(FakeAuthRepository.passwordOk);

      expect(await cubit.onSubmit(), isFalse);
      expect(cubit.state.error, 'Sin conexión');
    });
  });

  group('LoginScreen', () {
    Future<FakeAuthRepository> montar(WidgetTester tester) async {
      final repo = FakeAuthRepository();
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider(
          create: (_) => LoginFormCubit(authRepository: repo),
          child: const LoginScreen(),
        ),
      ));
      return repo;
    }

    FilledButton boton(WidgetTester tester) => tester
        .widget<FilledButton>(find.byKey(const Key('login_submit')));

    testWidgets('el botón se habilita al completar email y contraseña',
        (tester) async {
      await montar(tester);
      expect(boton(tester).onPressed, isNull);

      await tester.enterText(
          find.byKey(const Key('login_email')), FakeAuthRepository.emailOk);
      await tester.enterText(find.byKey(const Key('login_password')), 'x');
      await tester.pump();

      expect(boton(tester).onPressed, isNotNull);
    });

    testWidgets('credenciales incorrectas muestran el error en pantalla',
        (tester) async {
      await montar(tester);
      await tester.enterText(
          find.byKey(const Key('login_email')), FakeAuthRepository.emailOk);
      await tester.enterText(find.byKey(const Key('login_password')), 'mala');
      await tester.pump();

      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Email o contraseña incorrectos'), findsOneWidget);
    });

    testWidgets('credenciales correctas inician sesión', (tester) async {
      final repo = await montar(tester);
      await tester.enterText(
          find.byKey(const Key('login_email')), FakeAuthRepository.emailOk);
      await tester.enterText(find.byKey(const Key('login_password')),
          FakeAuthRepository.passwordOk);
      await tester.pump();

      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      expect(repo.haySesion, isTrue);
      expect(find.byKey(const Key('login_error')), findsNothing);
    });
  });
}
