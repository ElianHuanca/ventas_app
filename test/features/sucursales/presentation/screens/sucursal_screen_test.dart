import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

/// El fake compartido no guarda lo que recibe en create/update/delete:
/// esta subclase lo registra para verificarlo.
class _RepoRegistrador extends FakeSucursalesRepository {
  _RepoRegistrador({super.sucursales});

  final List<Map<String, dynamic>> creadas = [];
  final List<List<dynamic>> actualizadas = [];
  final List<int> eliminadas = [];
  Exception? errorGetSucursal;

  /// Si no es null, getSucursal espera a que se complete.
  Completer<void>? esperaGetSucursal;

  @override
  Future<Sucursal> getSucursal(int id) async {
    await esperaGetSucursal?.future;
    if (errorGetSucursal != null) throw errorGetSucursal!;
    return super.getSucursal(id);
  }

  @override
  Future<Sucursal> createSucursal(Map<String, dynamic> sucursalLike) {
    creadas.add(Map<String, dynamic>.from(sucursalLike));
    return super.createSucursal(sucursalLike);
  }

  @override
  Future<Sucursal> updateSucursal(Map<String, dynamic> sucursalLike, int id) {
    actualizadas.add([Map<String, dynamic>.from(sucursalLike), id]);
    return super.updateSucursal(sucursalLike, id);
  }

  @override
  Future<bool> deleteSucursal(int id) {
    eliminadas.add(id);
    return super.deleteSucursal(id);
  }
}

void main() {
  late _RepoRegistrador repo;
  late SucursalesBloc sucursalesBloc;
  late GoRouter router;

  final sucursales = [
    Sucursal(id: 1, nombre: 'Centro'),
    Sucursal(id: 2, nombre: 'Norte'),
  ];

  setUp(() {
    repo = _RepoRegistrador(sucursales: sucursales);
  });

  /// Monta la ruta `/sucursal/:id` como en app_router.dart (SucursalesBloc
  /// global + SucursalBloc de la ruta), empujada sobre un listado stub para
  /// que haya a dónde volver.
  Future<void> montar(WidgetTester tester, {required int id}) async {
    sucursalesBloc = SucursalesBloc(sucursalesRepository: repo);
    addTearDown(sucursalesBloc.close);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('STUB LISTADO')),
        ),
        GoRoute(
          path: '/sucursal/:idsucursal',
          builder: (_, state) {
            final id = int.parse(state.pathParameters['idsucursal']!);
            return BlocProvider(
              create: (_) => SucursalBloc(sucursalesRepository: repo, id: id),
              child: SucursalScreen(id: id),
            );
          },
        ),
        GoRoute(
          path: '/sucursal-disponibilidad/:idsucursal',
          builder: (_, state) => Scaffold(
              body: Text(
                  'STUB DISPONIBILIDAD ${state.pathParameters['idsucursal']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider.value(
      value: sucursalesBloc,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    unawaited(router.push('/sucursal/$id'));
    await tester.pumpAndSettle();
  }

  Finder campoNombre() => find.byType(TextFormField);

  group('crear (id 0)', () {
    testWidgets('muestra el formulario vacío con "Crear Sucursal" y "Guardar"',
        (tester) async {
      await montar(tester, id: 0);

      expect(find.text('Crear Sucursal'), findsOneWidget);
      expect(find.text('Nombre'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.text('Modificar'), findsNothing);
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.controller!.text, '');
    });

    testWidgets('no ofrece Eliminar ni la disponibilidad de telas',
        (tester) async {
      await montar(tester, id: 0);

      expect(find.text('Eliminar'), findsNothing);
      expect(find.text('Disponibilidad de telas'), findsNothing);
    });

    testWidgets('Guardar crea la sucursal, la agrega al listado y vuelve',
        (tester) async {
      await montar(tester, id: 0);

      await tester.enterText(campoNombre(), '  Sur ');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // El repo recibe el nombre sin espacios (el id 0 lo quita el datasource)
      expect(repo.creadas, [
        {'id': 0, 'nombre': 'Sur'},
      ]);
      expect(sucursalesBloc.state.sucursales.map((e) => e.nombre),
          ['Centro', 'Norte', 'Sur']);
      expect(find.text('Realizado correctamente'), findsOneWidget);
      expect(find.text('STUB LISTADO'), findsOneWidget);
    });

    testWidgets('con el nombre vacío no envía y muestra el error',
        (tester) async {
      await montar(tester, id: 0);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(repo.creadas, isEmpty);
      expect(sucursalesBloc.state.sucursales.length, 2);
      expect(find.text('Hubo un error'), findsOneWidget);
      // Se queda en el formulario
      expect(find.text('Crear Sucursal'), findsOneWidget);
    });

    testWidgets('si el repositorio falla avisa y se queda en el formulario',
        (tester) async {
      await montar(tester, id: 0);
      repo.error = Exception('sin conexión');

      await tester.enterText(campoNombre(), 'Sur');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('Crear Sucursal'), findsOneWidget);
      expect(sucursalesBloc.state.sucursales.length, 2);
    });
  });

  group('editar', () {
    testWidgets('precarga la sucursal con "Editar Sucursal" y "Modificar"',
        (tester) async {
      await montar(tester, id: 2);

      expect(find.text('Editar Sucursal'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Norte'), findsOneWidget);
      expect(find.text('Modificar'), findsOneWidget);
      expect(find.text('Guardar'), findsNothing);
      expect(find.text('Eliminar'), findsOneWidget);
      expect(find.text('Disponibilidad de telas'), findsOneWidget);
    });

    testWidgets('Modificar actualiza la sucursal en el listado y vuelve',
        (tester) async {
      await montar(tester, id: 2);

      await tester.enterText(campoNombre(), 'Norte II');
      await tester.tap(find.text('Modificar'));
      await tester.pumpAndSettle();

      expect(repo.creadas, isEmpty);
      expect(repo.actualizadas, [
        [
          {'id': 2, 'nombre': 'Norte II'},
          2,
        ],
      ]);
      expect(sucursalesBloc.state.sucursales.map((e) => e.nombre),
          ['Centro', 'Norte II']);
      expect(find.text('Realizado correctamente'), findsOneWidget);
      expect(find.text('STUB LISTADO'), findsOneWidget);
    });

    testWidgets('borrar el nombre y Modificar no envía', (tester) async {
      await montar(tester, id: 2);

      await tester.enterText(campoNombre(), '   ');
      await tester.tap(find.text('Modificar'));
      await tester.pumpAndSettle();

      expect(repo.actualizadas, isEmpty);
      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('Editar Sucursal'), findsOneWidget);
    });

    testWidgets('Eliminar da de baja la sucursal, la quita y vuelve',
        (tester) async {
      await montar(tester, id: 2);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(repo.eliminadas, [2]);
      expect(sucursalesBloc.state.sucursales.map((e) => e.id), [1]);
      expect(find.text('Realizado correctamente'), findsOneWidget);
      expect(find.text('STUB LISTADO'), findsOneWidget);
    });

    testWidgets('si la baja no se confirma avisa y conserva la sucursal',
        (tester) async {
      await montar(tester, id: 2);
      repo.deleteResult = false;

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(repo.eliminadas, [2]);
      expect(sucursalesBloc.state.sucursales.length, 2);
      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('Editar Sucursal'), findsOneWidget);
    });

    testWidgets('"Disponibilidad de telas" navega a la de esa sucursal',
        (tester) async {
      await montar(tester, id: 2);

      await tester.tap(find.text('Disponibilidad de telas'));
      await tester.pumpAndSettle();

      expect(find.text('STUB DISPONIBILIDAD 2'), findsOneWidget);
    });

    testWidgets('el botón volver regresa al listado sin guardar',
        (tester) async {
      await montar(tester, id: 2);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('STUB LISTADO'), findsOneWidget);
      expect(repo.actualizadas, isEmpty);
    });
  });

  testWidgets('mientras carga la sucursal muestra el loader', (tester) async {
    final espera = Completer<void>();
    repo.esperaGetSucursal = espera;
    sucursalesBloc = SucursalesBloc(sucursalesRepository: repo);
    addTearDown(sucursalesBloc.close);
    final sucursalBloc = SucursalBloc(sucursalesRepository: repo, id: 1);
    addTearDown(sucursalBloc.close);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sucursalesBloc),
        BlocProvider.value(value: sucursalBloc),
      ],
      child: const MaterialApp(home: SucursalScreen(id: 1)),
    ));

    expect(find.byType(FullScreenLoader), findsOneWidget);
    expect(find.text('Editar Sucursal'), findsNothing);

    espera.complete();
    await tester.pumpAndSettle();
    expect(find.byType(FullScreenLoader), findsNothing);
    expect(find.text('Editar Sucursal'), findsOneWidget);
  });

  testWidgets(
    'si falla la carga de la sucursal la pantalla no se rompe',
    (tester) async {
      repo.errorGetSucursal = Exception('sin conexión');
      await montar(tester, id: 2);

      expect(tester.takeException(), isNull);
    },
  );
}
