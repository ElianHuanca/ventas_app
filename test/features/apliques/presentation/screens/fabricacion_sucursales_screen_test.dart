import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../../../../helpers/fake_repositories.dart';

/// Repo cuya carga de sucursales queda pendiente hasta completar [carga].
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
    Sucursal(id: 7, nombre: 'Casa Central'),
    Sucursal(id: 9, nombre: 'Mercado Campesino'),
  ];

  setUp(() {
    repo = FakeSucursalesRepository(sucursales: sucursales);
  });

  Future<void> montar(WidgetTester tester, {bool esperar = true}) async {
    // El SucursalesBloc es global en la app (main.dart): acá se inyecta
    bloc = SucursalesBloc(sucursalesRepository: repo);
    addTearDown(bloc.close);
    router = GoRouter(
      initialLocation: '/fabricacion',
      routes: [
        GoRoute(
          path: '/fabricacion',
          builder: (_, __) => const FabricacionSucursalesScreen(),
        ),
        GoRoute(
          path: '/fabricacion/:idsucursal',
          builder: (_, state) => Scaffold(
            body:
                Text('STUB PRODUCCIONES ${state.pathParameters['idsucursal']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(BlocProvider.value(
      value: bloc,
      child: MaterialApp.router(routerConfig: router),
    ));
    if (esperar) await tester.pumpAndSettle();
  }

  group('FabricacionSucursalesScreen', () {
    testWidgets('muestra el título y una tarjeta por sucursal en mayúsculas',
        (tester) async {
      await montar(tester);

      expect(find.text('Fabricación'), findsOneWidget);
      expect(find.byType(ItemDashboard), findsNWidgets(2));
      expect(find.text('CASA CENTRAL'), findsOneWidget);
      expect(find.text('MERCADO CAMPESINO'), findsOneWidget);
      // El nombre tal cual viene del repo no se muestra
      expect(find.text('Casa Central'), findsNothing);
      expect(find.byIcon(Icons.store), findsNWidgets(2));
    });

    testWidgets('es pantalla de menú: sin botón atrás ni botón +',
        (tester) async {
      await montar(tester);

      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('tocar una sucursal navega a /fabricacion/:idsucursal',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('MERCADO CAMPESINO'));
      await tester.pumpAndSettle();

      expect(find.text('STUB PRODUCCIONES 9'), findsOneWidget);

      // Es un push: al volver sigue el listado
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('CASA CENTRAL'), findsOneWidget);
    });

    testWidgets('mientras carga muestra el loader y ninguna tarjeta',
        (tester) async {
      final lento = _RepoLento();
      repo = lento;
      await montar(tester, esperar: false);
      await tester.pump();

      expect(find.byType(FullScreenLoader), findsOneWidget);
      expect(find.byType(ItemDashboard), findsNothing);

      lento.carga.complete(sucursales);
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenLoader), findsNothing);
      expect(find.text('CASA CENTRAL'), findsOneWidget);
    });

    testWidgets('sin sucursales no muestra tarjetas', (tester) async {
      repo = FakeSucursalesRepository();
      await montar(tester);

      expect(find.text('Fabricación'), findsOneWidget);
      expect(find.byType(ItemDashboard), findsNothing);
    });
  });
}
