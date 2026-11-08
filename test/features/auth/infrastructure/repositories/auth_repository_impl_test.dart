import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:textiles_app/features/auth/auth.dart';

import '../../../../helpers/base_falsa.dart';

// Sin red, con el cliente de Supabase Auth de verdad (gotrue): no es un fake
// que lanza AuthFallo. gotrue envuelve la falla de red en
// AuthRetryableFetchException (una AuthException), así que AuthRepositoryImpl
// la traduce como cualquier otro error de Auth: "No se pudo iniciar sesión"
// (ver el `revisar:` del escenario "Sin conexión" en openspec/specs/sesion).
void main() {
  final base = usarBaseFalsa();

  test(
      'sin red el cliente de Auth lo informa como error de autenticación y se '
      'traduce a "No se pudo iniciar sesión"', () async {
    base.sinConexion = true;

    // El error crudo: lo que recibe AuthRepositoryImpl
    await expectLater(
      Supabase.instance.client.auth
          .signInWithPassword(email: 'a@b.com', password: 'secreta'),
      throwsA(isA<AuthRetryableFetchException>()
          .having((e) => e, 'es AuthException', isA<AuthException>())),
    );
    // Lo que muestra la app
    await expectLater(
      AuthRepositoryImpl()
          .iniciarSesion(email: 'a@b.com', password: 'secreta'),
      throwsA(isA<AuthFallo>()
          .having((e) => e.mensaje, 'mensaje', 'No se pudo iniciar sesión')),
    );
    expect(base.pedidos.map((p) => p.url.path),
        everyElement('/auth/v1/token'));
    expect(AuthRepositoryImpl().haySesion, isFalse);
  });

  testWidgets(
      'sin red la pantalla de ingreso muestra "No se pudo iniciar sesión" y '
      'deja reintentar', (tester) async {
    base.sinConexion = true;
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider(
        create: (_) => LoginFormCubit(authRepository: AuthRepositoryImpl()),
        child: const LoginScreen(),
      ),
    ));
    await tester.enterText(
        find.byKey(const Key('login_email')), 'vendedora@huantex.com');
    await tester.enterText(find.byKey(const Key('login_password')), 'secreta');
    await tester.pump();

    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo iniciar sesión'), findsOneWidget);
    // El texto de la rama `catch (_)` no aparece: la falla de red es de Auth
    expect(find.textContaining('Sin conexión'), findsNothing);
    final boton = tester
        .widget<FilledButton>(find.byKey(const Key('login_submit')));
    expect(boton.onPressed, isNotNull);
  });
}
