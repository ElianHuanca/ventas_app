import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';

void main() {
  group('Screen1', () {
    testWidgets('con onTap muestra el botón add en el AppBar y lo ejecuta',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Screen1(
          widget: const [Text('contenido')],
          title: 'Titulo',
          isGridview: false,
          backRoute: true,
          onTap: () => taps++,
        ),
      ));

      expect(find.text('Titulo'), findsOneWidget);
      expect(find.text('contenido'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      expect(taps, 1);
    });

    testWidgets('sin onTap no muestra el botón add', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Screen1(
          widget: [Text('contenido')],
          title: 'Titulo',
          isGridview: false,
          backRoute: true,
        ),
      ));

      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('backRoute true muestra BackButton; false no', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Screen1(
          widget: [Text('a')],
          title: 'Con back',
          isGridview: false,
          backRoute: true,
        ),
      ));
      expect(find.byType(BackButton), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(
        home: Screen1(
          widget: [Text('b')],
          title: 'Sin back',
          isGridview: false,
          backRoute: false,
        ),
      ));
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('isGridview usa GridView; si no, ListView', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Screen1(
          widget: [Text('a')],
          title: 'Grid',
          isGridview: true,
          backRoute: true,
        ),
      ));
      expect(find.byType(GridView), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(
        home: Screen1(
          widget: [Text('b')],
          title: 'Lista',
          isGridview: false,
          backRoute: true,
        ),
      ));
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('las pantallas raíz (sin backRoute) tienen el menú lateral',
        (tester) async {
      for (final backRoute in [false, true]) {
        await tester.pumpWidget(MaterialApp(
          home: Screen1(
            widget: const [Text('a')],
            title: 'T',
            isGridview: false,
            backRoute: backRoute,
          ),
        ));
        expect(tester.state<ScaffoldState>(find.byType(Scaffold)).hasDrawer,
            !backRoute,
            reason: 'backRoute: $backRoute');
      }
    });

    testWidgets('el BackButton vuelve a la pantalla anterior del router',
        (tester) async {
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/detalle'),
              child: const Text('ir'),
            ),
          ),
        ),
        GoRoute(
          path: '/detalle',
          builder: (_, __) => const Screen1(
            widget: [Text('detalle')],
            title: 'Detalle',
            isGridview: false,
            backRoute: true,
          ),
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.tap(find.text('ir'));
      await tester.pumpAndSettle();
      expect(find.text('detalle'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('detalle'), findsNothing);
      expect(find.text('ir'), findsOneWidget);
    });

    testWidgets('tocar fuera de un campo cierra el teclado', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Screen1(
          widget: [TextField(), SizedBox(height: 300, child: Text('fondo'))],
          title: 'Form',
          isGridview: false,
          backRoute: true,
        ),
      ));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.text('fondo'));
      await tester.pump();

      expect(tester.testTextInput.isVisible, isFalse);
    });
  });
}
