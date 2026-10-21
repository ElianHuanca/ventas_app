import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

/// Deja la carga de ventas en espera hasta completar [carga].
class _RepoConCargaPendiente extends FakeVentasRepository {
  final carga = Completer<List<Venta>>();

  @override
  Future<List<Venta>> getVentas(int idsucursal) => carga.future;
}

Venta _venta(int id, DateTime fecha) => Venta(
      id: id,
      fecha: fecha,
      total: 100,
      ganancias: 40,
      descuento: 0,
      idsucursales: 3,
    );

void main() {
  late FakeVentasRepository repo;
  late VentasBloc bloc;
  late GoRouter router;

  final ventas = [
    _venta(1, DateTime(2024, 5, 10)),
    _venta(2, DateTime(2024, 5, 9)),
  ];

  setUp(() {
    repo = FakeVentasRepository(ventas: ventas);
  });

  /// Con [asentar] en false no espera a que termine la carga (el loader
  /// anima indefinidamente y pumpAndSettle no terminaría).
  Future<void> montar(WidgetTester tester, {bool asentar = true}) async {
    bloc = VentasBloc(ventasRepository: repo, idsucursal: 3);
    addTearDown(bloc.close);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider.value(
            value: bloc,
            child: const VentasScreen(idsucursal: 3),
          ),
        ),
        GoRoute(
          path: '/det_venta/:idsucursal',
          builder: (_, state) => Scaffold(
              body:
                  Text('STUB REGISTRO ${state.pathParameters['idsucursal']}')),
        ),
        GoRoute(
          path: '/det_ventas/:idventa',
          builder: (_, state) => Scaffold(
              body: Text('STUB DETALLE ${state.pathParameters['idventa']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    asentar ? await tester.pumpAndSettle() : await tester.pump();
  }

  testWidgets('muestra el loader mientras cargan las ventas', (tester) async {
    final pendiente = _RepoConCargaPendiente();
    repo = pendiente;
    await montar(tester, asentar: false);

    expect(find.byType(FullScreenLoader), findsOneWidget);
    expect(find.byType(ItemDashboard), findsNothing);

    pendiente.carga.complete(ventas);
    await tester.pumpAndSettle();

    expect(find.byType(FullScreenLoader), findsNothing);
    expect(find.byType(ItemDashboard), findsNWidgets(2));
  });

  testWidgets('muestra una tarjeta por venta con su fecha', (tester) async {
    await montar(tester);

    expect(find.text('Ventas'), findsOneWidget);
    expect(find.byType(ItemDashboard), findsNWidgets(2));
    // ItemDashboard muestra el título en mayúsculas (la fecha no cambia)
    expect(find.text(changeFormatDate(DateTime(2024, 5, 10)).toUpperCase()),
        findsOneWidget);
    expect(find.text('10-5-2024'), findsOneWidget);
    expect(find.text('9-5-2024'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_rounded), findsNWidgets(2));
    expect(repo.lastGetVentasSucursalId, 3);
  });

  testWidgets('sin ventas no muestra tarjetas pero sí el botón +',
      (tester) async {
    repo.ventas = const [];
    await montar(tester);

    expect(find.byType(ItemDashboard), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('el botón + abre el registro de la sucursal y recarga al volver',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('STUB REGISTRO 3'), findsOneWidget);

    // Mientras tanto se registró una venta nueva
    repo.ventas = [_venta(3, DateTime(2024, 5, 11)), ...ventas];
    router.pop();
    await tester.pumpAndSettle();

    expect(repo.getVentasCalls, 2);
    expect(find.text('11-5-2024'), findsOneWidget);
    expect(find.byType(ItemDashboard), findsNWidgets(3));
  });

  testWidgets(
      'tap en una tarjeta abre el detalle de esa venta y recarga al volver',
      (tester) async {
    await montar(tester);

    await tester.tap(find.text('9-5-2024'));
    await tester.pumpAndSettle();
    expect(find.text('STUB DETALLE 2'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(repo.getVentasCalls, 2);
    expect(find.text('9-5-2024'), findsOneWidget);
  });
}
