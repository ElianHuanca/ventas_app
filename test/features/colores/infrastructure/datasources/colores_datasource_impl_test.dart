import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/colores/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/colores/presentation/screens/screens.dart';

import '../../../../helpers/base_falsa.dart';

// El alta de un color con la pila de la app (ColorScreen → ColoresBloc →
// ColoresRepositoryImpl → ColoresDatasourceImpl → cliente de Supabase) contra
// la BaseFalsa, que responde como PostgREST cuando choca el UNIQUE
// `colores_nombre_key`. Que la base de verdad tenga ese UNIQUE (y que incluya
// las filas dadas de baja) es de pgTAP: acá se prueba lo que hace la app con
// ese rechazo.
void main() {
  final base = usarBaseFalsa();

  /// `colores` como en el esquema: `activo` default true y UNIQUE (nombre)
  /// sobre todas las filas.
  void colores(List<Fila> filas) => base.tabla('colores', filas,
      defaults: {'hex': null, 'activo': true},
      unicos: [
        ('colores_nombre_key', ['nombre']),
      ]);

  /// La lista (stub) con /color/0 encima, y el bloc armado como en
  /// app_router.
  Future<void> montarAlta(WidgetTester tester) async {
    final bloc = ColoresBloc(
      coloresRepository: ColoresRepositoryImpl(ColoresDatasourceImpl()),
    );
    addTearDown(bloc.close);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('STUB LISTA')),
        ),
        GoRoute(
          path: '/color/:idcolor',
          builder: (_, __) =>
              BlocProvider.value(value: bloc, child: const ColorScreen(id: 0)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    unawaited(router.push('/color/0'));
    await tester.pumpAndSettle();
  }

  Finder campo(String label) => find.widgetWithText(TextFormField, label);

  Future<void> guardar(WidgetTester tester, String nombre, String hex) async {
    await tester.enterText(campo('Nombre'), nombre);
    await tester.enterText(campo('Hex (ej: C0392B)'), hex);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
  }

  bool huboAlta() => base.pedidos
      .any((p) => p.method == 'POST' && p.url.path == '/rest/v1/colores');

  group('nombre repetido', () {
    testWidgets(
        'dado de baja: la base rechaza el alta, se ve "Hubo un error" y el '
        'formulario sigue abierto', (tester) async {
      colores([
        {'id': 3, 'nombre': 'Coral', 'hex': 'FF7F50', 'activo': false},
      ]);
      await montarAlta(tester);

      await guardar(tester, ' Coral ', '#ff7f50');

      // El dado de baja no está en la lista (solo se cargan los activos):
      // la app no puede saberlo y manda el alta, que la base rechaza
      expect(huboAlta(), isTrue);
      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('Realizado correctamente'), findsNothing);
      expect(find.text('Crear Color'), findsOneWidget);
      expect(find.text('STUB LISTA'), findsNothing);
      expect(base.filas('colores'), hasLength(1));
    });

    testWidgets('activo: la base rechaza el alta y se ve "Hubo un error"',
        (tester) async {
      colores([
        {'id': 3, 'nombre': 'Coral', 'hex': 'FF7F50', 'activo': true},
      ]);
      await montarAlta(tester);

      await guardar(tester, 'Coral', 'E9967A');

      expect(huboAlta(), isTrue);
      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('Crear Color'), findsOneWidget);
      expect(base.filas('colores'), hasLength(1));
    });

    testWidgets('con otro nombre el alta pasa (la base falsa no rechaza todo)',
        (tester) async {
      colores([
        {'id': 3, 'nombre': 'Coral', 'hex': 'FF7F50', 'activo': false},
      ]);
      await montarAlta(tester);

      await guardar(tester, 'Salmón', 'FA8072');

      expect(find.text('Realizado correctamente'), findsOneWidget);
      expect(find.text('STUB LISTA'), findsOneWidget);
      expect(base.filas('colores').last,
          {'id': 4, 'nombre': 'Salmón', 'hex': 'FA8072', 'activo': true});
    });
  });
}
