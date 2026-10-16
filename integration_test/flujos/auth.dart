import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/config/config.dart';

import '../helpers.dart';

void authTests() {
  group('login', () {
    testWidgets(
        'exige ambos campos, rechaza credenciales malas, entra con las '
        'buenas y cierra sesión', (tester) async {
      await cerrarSesionDirecto();
      await montarApp(tester);

      // Sin sesión el router manda a /login
      final email = find.byKey(const Key('login_email'));
      final password = find.byKey(const Key('login_password'));
      final ingresar = find.byKey(const Key('login_submit'));
      expect(email, findsOneWidget);
      expect(tester.widget<FilledButton>(ingresar).onPressed, isNull);

      await escribir(tester, email, emailPrueba);
      expect(tester.widget<FilledButton>(ingresar).onPressed, isNull,
          reason: 'sin contraseña no se puede enviar');

      await escribir(tester, password, 'no-es-la-contraseña');
      await tester.tap(ingresar);
      await esperarHasta(tester, find.byKey(const Key('login_error')));
      expect(find.text('Email o contraseña incorrectos'), findsOneWidget);
      expect(SupabaseConfig.client.auth.currentSession, isNull);

      await escribir(tester, password, passwordPrueba);
      await tester.tap(ingresar);
      await esperarHasta(tester, find.text('Sucursales'));
      expect(SupabaseConfig.client.auth.currentUser?.email, emailPrueba);

      // El menú muestra la cuenta y permite salir
      await abrirMenu(tester);
      expect(find.text(emailPrueba), findsOneWidget);
      // Al pie del menú: en un celular chico queda debajo del borde
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await esperarHasta(tester, email);
      expect(SupabaseConfig.client.auth.currentSession, isNull);
    });
  });
}
