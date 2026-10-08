import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/shared/shared.dart';

import '../../../../helpers/fake_repositories.dart';

/// Cuenta las cargas del historial para verificar las recargas al volver.
class _Repo extends FakeVentasApliquesRepository {
  _Repo({super.ventas});

  int getVentasCalls = 0;

  @override
  Future<List<VentaAplique>> getVentasApliques(int idsucursal) {
    getVentasCalls++;
    return super.getVentasApliques(idsucursal);
  }
}

void main() {
  late _Repo repo;
  late VentasApliquesBloc bloc;
  late GoRouter router;

  final ventas = [
    VentaAplique(id: 21, fecha: DateTime(2024, 5, 10)),
    VentaAplique(id: 20, fecha: DateTime(2024, 5, 9)),
  ];

  setUp(() {
    repo = _Repo(ventas: ventas);
  });

  Future<void> montar(WidgetTester tester) async {
    bloc = VentasApliquesBloc(ventasApliquesRepository: repo, idsucursal: 3);
    addTearDown(bloc.close);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => BlocProvider.value(
            value: bloc,
            child: const VentasApliquesScreen(idsucursal: 3),
          ),
        ),
        GoRoute(
          path: '/venta-apliques/registro/:idsucursal',
          builder: (_, state) => Scaffold(
            body: Text('STUB REGISTRO ${state.pathParameters['idsucursal']}'),
          ),
        ),
        GoRoute(
          path: '/venta-apliques/detalle/:idventa',
          builder: (_, state) => Scaffold(
            body: Column(children: [
              Text('STUB DETALLE ${state.pathParameters['idventa']}'),
              Text('FECHA ${state.uri.queryParameters['fecha']}'),
            ]),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra una tarjeta por fecha, el título y el botón +',
      (tester) async {
    await montar(tester);

    expect(find.text('Venta de Apliques'), findsOneWidget);
    expect(find.byType(ItemDashboard), findsNWidgets(2));
    expect(find.text('10-5-2024'), findsOneWidget);
    expect(find.text('9-5-2024'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    // Pide el historial de la sucursal de la pantalla
    expect(repo.lastGetVentasApliquesSucursalId, 3);
    expect(repo.getVentasCalls, 1);
  });

  testWidgets('sin ventas no muestra tarjetas pero sí el botón +',
      (tester) async {
    repo = _Repo();
    await montar(tester);

    expect(find.byType(ItemDashboard), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets(
      'el botón + navega al registro de la sucursal y recarga al volver',
      (tester) async {
    await montar(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('STUB REGISTRO 3'), findsOneWidget);

    // Mientras tanto se registró la venta de hoy
    repo.ventas = [
      VentaAplique(id: 22, fecha: DateTime(2024, 5, 11)),
      ...ventas,
    ];
    router.pop();
    await tester.pumpAndSettle();

    expect(repo.getVentasCalls, 2);
    expect(repo.lastGetVentasApliquesSucursalId, 3);
    expect(find.text('11-5-2024'), findsOneWidget);
    expect(find.byType(ItemDashboard), findsNWidgets(3));
  });

  testWidgets(
      'tap en una fecha navega al detalle con idventa y fecha ISO, y recarga '
      'al volver', (tester) async {
    await montar(tester);

    await tester.tap(find.text('9-5-2024'));
    await tester.pumpAndSettle();

    expect(find.text('STUB DETALLE 20'), findsOneWidget);
    expect(find.text('FECHA ${DateTime(2024, 5, 9).toIso8601String()}'),
        findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text('9-5-2024'), findsOneWidget);
    expect(repo.getVentasCalls, 2);
  });
}
