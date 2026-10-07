import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:textiles_app/features/dashboard/presentation/screens/dashboard_screen.dart';

import '../../helpers/fake_repositories.dart';

void main() {
  // Las RPC devuelven los rankings ordenados por monto
  const topTelas = [
    TopProducto(nombre: 'Lino', totalVendido: 500, totalCantidad: 10),
    TopProducto(nombre: 'Seda', totalVendido: 300, totalCantidad: 12.5),
  ];
  const topApliques = [
    TopProducto(nombre: 'Flor', totalVendido: 200, totalCantidad: 4),
    TopProducto(nombre: 'Mariposa', totalVendido: 90, totalCantidad: 9),
  ];
  const resumenTelas = ResumenVentas(total: 800, ganancias: 250, descuento: 5);
  const resumenApliques =
      ResumenVentas(total: 290, ganancias: 100, descuento: 0);

  late FakeDashboardRepository repo;

  setUp(() {
    repo = FakeDashboardRepository(
      topTelas: topTelas,
      topApliques: topApliques,
      resumenTelas: resumenTelas,
      resumenApliques: resumenApliques,
    );
  });

  group('DashboardCubit', () {
    test('carga el top y el resumen de telas y de apliques', () async {
      final cubit = DashboardCubit(repository: repo);
      await cubit.cargar();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.topTelas, topTelas);
      expect(cubit.state.topApliques, topApliques);
      expect(cubit.state.resumenTelas, resumenTelas);
      expect(cubit.state.resumenApliques, resumenApliques);
      await cubit.close();
    });

    test('por cantidad reordena ambos rankings sin volver a consultar',
        () async {
      final cubit = DashboardCubit(repository: repo);
      await cubit.cargar();
      final consultas = repo.rangos.length;

      cubit.toggleVista();

      expect(cubit.state.telasOrdenadas.map((p) => p.nombre),
          ['Seda', 'Lino']);
      expect(cubit.state.apliquesOrdenados.map((p) => p.nombre),
          ['Mariposa', 'Flor']);
      expect(repo.rangos.length, consultas);

      cubit.toggleVista();
      expect(cubit.state.telasOrdenadas.map((p) => p.nombre),
          ['Lino', 'Seda']);
      await cubit.close();
    });

    test('cambiarRango consulta las cuatro RPC con el rango nuevo', () async {
      final cubit = DashboardCubit(repository: repo);
      await cubit.cargar();
      repo.rangos.clear();

      final desde = DateTime(2026, 9, 1);
      final hasta = DateTime(2026, 9, 30);
      await cubit.cambiarRango(desde, hasta);

      expect(repo.rangos, hasLength(4));
      expect(repo.rangos.every((r) => r[0] == desde && r[1] == hasta), isTrue);
      expect(cubit.state.desde, desde);
      expect(cubit.state.hasta, hasta);
      await cubit.close();
    });
  });

  group('DashboardScreen', () {
    Future<DashboardCubit> montar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final cubit = DashboardCubit(repository: repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const DashboardScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      return cubit;
    }

    testWidgets('abre en Telas y muestra Apliques en su propia pestaña',
        (tester) async {
      await montar(tester);

      expect(find.text('Lino'), findsOneWidget);
      expect(find.text('2 telas por total vendido'), findsOneWidget);
      expect(find.text('800.00 Bs'), findsOneWidget); // resumen telas
      expect(find.text('Flor'), findsNothing);

      await tester.tap(find.text('Apliques'));
      await tester.pumpAndSettle();

      expect(find.text('Flor'), findsOneWidget);
      expect(find.text('Mariposa'), findsOneWidget);
      expect(find.text('2 apliques por total vendido'), findsOneWidget);
      expect(find.text('290.00 Bs'), findsOneWidget); // resumen apliques
      expect(find.text('Lino'), findsNothing);
    });

    testWidgets('por cantidad: metros en telas, unidades en apliques',
        (tester) async {
      await montar(tester);

      await tester.tap(find.text('Por cantidad'));
      await tester.pumpAndSettle();
      expect(find.text('12.50 mts'), findsOneWidget);
      expect(find.text('10 mts'), findsOneWidget);

      await tester.tap(find.text('Apliques'));
      await tester.pumpAndSettle();
      expect(find.text('9 uds'), findsOneWidget);
      expect(find.text('4 uds'), findsOneWidget);
    });

    testWidgets('pestaña sin ventas muestra su aviso', (tester) async {
      repo.topApliques = const [];
      await montar(tester);

      await tester.tap(find.text('Apliques'));
      await tester.pumpAndSettle();

      expect(find.text('Sin ventas de apliques en el período seleccionado'),
          findsOneWidget);
    });
  });
}
