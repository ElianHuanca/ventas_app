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

/// Repo cuya carga de sucursales no termina hasta completar [carga].
class _RepoLento extends FakeSucursalesRepository {
  final carga = Completer<List<Sucursal>>();

  @override
  Future<List<Sucursal>> getSucursales() => carga.future;
}

void main() {
  late FakeSucursalesRepository repo;
  late SucursalesBloc bloc;
  late GoRouter router;

  final sucursales = [
    Sucursal(id: 1, nombre: 'Centro'),
    Sucursal(id: 2, nombre: 'Norte'),
  ];

  setUp(() {
    repo = FakeSucursalesRepository(sucursales: sucursales);
  });

  /// [gestion] es el parámetro de la pantalla: false = inicio (venta de
  /// telas), true = gestión de sucursales.
  Future<void> montar(WidgetTester tester, {required bool gestion}) async {
    // Vista alta: la grilla tiene celdas cuadradas de media pantalla
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // El SucursalesBloc es global en la app (lib/main.dart)
    bloc = SucursalesBloc(sucursalesRepository: repo);
    addTearDown(bloc.close);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => SucursalesScreen(gestion),
        ),
        GoRoute(
          path: '/ventas/:idsucursal',
          builder: (_, state) => Scaffold(
              body: Text('STUB VENTAS ${state.pathParameters['idsucursal']}')),
        ),
        GoRoute(
          path: '/sucursal/:idsucursal',
          builder: (_, state) => Scaffold(
              body:
                  Text('STUB SUCURSAL ${state.pathParameters['idsucursal']}')),
        ),
      ],
    );
    await tester.pumpWidget(BlocProvider.value(
      value: bloc,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  group('inicio (venta de telas)', () {
    testWidgets('muestra una tarjeta por sucursal con el nombre en mayúsculas',
        (tester) async {
      await montar(tester, gestion: false);

      expect(find.text('Sucursales'), findsOneWidget);
      expect(find.byType(ItemDashboard), findsNWidgets(2));
      expect(find.text('CENTRO'), findsOneWidget);
      expect(find.text('NORTE'), findsOneWidget);
    });

    testWidgets('no ofrece la tarjeta para agregar sucursal', (tester) async {
      await montar(tester, gestion: false);

      expect(find.byIcon(Icons.add_business_rounded), findsNothing);
      expect(find.text('AGREGAR SUCUSAL'), findsNothing);
    });

    testWidgets('es pantalla raíz: tiene menú lateral y no botón volver',
        (tester) async {
      await montar(tester, gestion: false);

      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('tocar una sucursal navega a sus ventas', (tester) async {
      await montar(tester, gestion: false);

      await tester.tap(find.text('NORTE'));
      await tester.pumpAndSettle();
      expect(find.text('STUB VENTAS 2'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('NORTE'), findsOneWidget);
    });
  });

  group('gestión de sucursales', () {
    testWidgets('muestra las sucursales y la tarjeta para agregar',
        (tester) async {
      await montar(tester, gestion: true);

      expect(find.byType(ItemDashboard), findsNWidgets(3));
      expect(find.text('CENTRO'), findsOneWidget);
      expect(find.text('NORTE'), findsOneWidget);
      // (sic) el texto en lib/ dice "Agregar Sucusal"
      expect(find.text('AGREGAR SUCUSAL'), findsOneWidget);
      expect(find.byIcon(Icons.add_business_rounded), findsOneWidget);
    });

    testWidgets('la tarjeta para agregar navega al formulario con id 0',
        (tester) async {
      await montar(tester, gestion: true);

      await tester.tap(find.byIcon(Icons.add_business_rounded));
      await tester.pumpAndSettle();

      expect(find.text('STUB SUCURSAL 0'), findsOneWidget);
    });

    testWidgets('tocar una sucursal navega a su formulario', (tester) async {
      await montar(tester, gestion: true);

      await tester.tap(find.text('CENTRO'));
      await tester.pumpAndSettle();

      expect(find.text('STUB SUCURSAL 1'), findsOneWidget);
      expect(find.text('STUB VENTAS 1'), findsNothing);
    });

    testWidgets('sin sucursales solo queda la tarjeta para agregar',
        (tester) async {
      repo = FakeSucursalesRepository();
      await montar(tester, gestion: true);

      expect(find.byType(ItemDashboard), findsOneWidget);
      expect(find.byIcon(Icons.add_business_rounded), findsOneWidget);
    });

    testWidgets('refleja una sucursal creada en el bloc global',
        (tester) async {
      await montar(tester, gestion: true);

      await bloc.createSucursal({'nombre': 'Sur'});
      await tester.pumpAndSettle();

      expect(find.text('SUR'), findsOneWidget);
      expect(find.byType(ItemDashboard), findsNWidgets(4));
    });
  });

  testWidgets('mientras carga muestra el loader en vez de las tarjetas',
      (tester) async {
    final lento = _RepoLento();
    repo = lento;
    bloc = SucursalesBloc(sucursalesRepository: repo);
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider.value(
      value: bloc,
      child: const MaterialApp(home: SucursalesScreen(false)),
    ));
    await tester.pump();

    expect(find.byType(FullScreenLoader), findsOneWidget);
    expect(find.byType(ItemDashboard), findsNothing);

    lento.carga.complete(sucursales);
    await tester.pumpAndSettle();

    expect(find.byType(FullScreenLoader), findsNothing);
    expect(find.text('CENTRO'), findsOneWidget);
  });
}
