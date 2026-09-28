import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
