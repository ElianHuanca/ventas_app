import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';

void main() {
  group('showSnackbar', () {
    Future<void> montar(WidgetTester tester) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () => showSnackbar(context, 'Primero'),
                    child: const Text('uno'),
                  ),
                  TextButton(
                    onPressed: () => showSnackbar(context, 'Segundo'),
                    child: const Text('dos'),
                  ),
                ],
              ),
            ),
          ),
        ));

    testWidgets('muestra el texto recibido', (tester) async {
      await montar(tester);

      await tester.tap(find.text('uno'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SnackBar, 'Primero'), findsOneWidget);
    });

    testWidgets('reemplaza el snackbar anterior en vez de encolarlo',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('uno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('dos'));
      await tester.pumpAndSettle();

      expect(find.text('Primero'), findsNothing);
      expect(find.widgetWithText(SnackBar, 'Segundo'), findsOneWidget);
    });
  });

  group('showSnackbarBool', () {
    late GoRouter router;

    /// Pantalla con un botón por cada forma de llamar a showSnackbarBool.
    Widget formulario() => Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                const Text('FORMULARIO'),
                TextButton(
                  onPressed: () => showSnackbarBool(context, true),
                  child: const Text('ok'),
                ),
                TextButton(
                  onPressed: () => showSnackbarBool(context, false),
                  child: const Text('falla'),
                ),
                TextButton(
                  onPressed: () =>
                      showSnackbarBool(context, true, popOnSuccess: false),
                  child: const Text('ok sin volver'),
                ),
              ],
            ),
          ),
        );

    /// Con [anterior] el formulario se empuja sobre otra pantalla (hay a
    /// dónde volver); sin él es la pantalla raíz.
    Future<void> montar(WidgetTester tester, {bool anterior = true}) async {
      router = GoRouter(
        initialLocation: anterior ? '/' : '/form',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('ANTERIOR')),
          ),
          GoRoute(path: '/form', builder: (_, __) => formulario()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      if (anterior) {
        router.push('/form');
        await tester.pumpAndSettle();
      }
    }

    testWidgets('éxito muestra "Realizado correctamente" y vuelve atrás',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('ok'));
      await tester.pumpAndSettle();

      expect(find.text('Realizado correctamente'), findsOneWidget);
      expect(find.text('ANTERIOR'), findsOneWidget);
      expect(find.text('FORMULARIO'), findsNothing);
    });

    testWidgets('error muestra "Hubo un error" y se queda en la pantalla',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('falla'));
      await tester.pumpAndSettle();

      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('FORMULARIO'), findsOneWidget);
    });

    testWidgets('popOnSuccess false avisa el éxito sin volver', (tester) async {
      await montar(tester);

      await tester.tap(find.text('ok sin volver'));
      await tester.pumpAndSettle();

      expect(find.text('Realizado correctamente'), findsOneWidget);
      expect(find.text('FORMULARIO'), findsOneWidget);
    });

    testWidgets('éxito sin pantalla anterior no intenta volver',
        (tester) async {
      await montar(tester, anterior: false);

      await tester.tap(find.text('ok'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Realizado correctamente'), findsOneWidget);
      expect(find.text('FORMULARIO'), findsOneWidget);
    });

    testWidgets('un aviso nuevo reemplaza al anterior', (tester) async {
      await montar(tester);

      await tester.tap(find.text('falla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ok sin volver'));
      await tester.pumpAndSettle();

      expect(find.text('Hubo un error'), findsNothing);
      expect(find.text('Realizado correctamente'), findsOneWidget);
    });
  });
}
