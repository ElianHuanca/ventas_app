import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late GoRouter router;

  Future<void> montar(WidgetTester tester) async {
    // El SucursalesBloc es global en la app (main.dart): acá se inyecta
    final bloc = SucursalesBloc(
      sucursalesRepository: FakeSucursalesRepository(sucursales: [
        Sucursal(id: 1, nombre: 'Shopping Miami'),
        Sucursal(id: 2, nombre: 'Ramada'),
      ]),
    );
    addTearDown(bloc.close);
    router = GoRouter(
      initialLocation: '/inventario',
      routes: [
        GoRoute(
          path: '/inventario',
          builder: (_, __) => const InventarioSucursalesScreen(),
        ),
        GoRoute(
          path: '/inventario/:idsucursal',
          builder: (_, state) => Scaffold(
            body: Text('STUB INVENTARIO ${state.pathParameters['idsucursal']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider.value(
      value: bloc,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el título y una tarjeta por sucursal, sin botón atrás',
      (tester) async {
    await montar(tester);

    expect(find.text('Inventario'), findsOneWidget);
    expect(find.byType(ItemDashboard), findsNWidgets(2));
    expect(find.text('SHOPPING MIAMI'), findsOneWidget);
    expect(find.text('RAMADA'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('tocar una sucursal abre su inventario (push)', (tester) async {
    await montar(tester);

    await tester.tap(find.text('RAMADA'));
    await tester.pumpAndSettle();

    expect(find.text('STUB INVENTARIO 2'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('SHOPPING MIAMI'), findsOneWidget);
  });
}
