import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

const _grande = 'Flor Petalo Suizo Grande - Bolsa x100 und';
const _mariposa = 'Mariposa Lentejuela 8x6 - Bolsa x50 und';

/// Ramada: poco stock de lo que más se vende.
const _ramada = [
  StockConVentas(
      apliqueId: 1,
      aplique: _grande,
      colorId: 1,
      color: 'Rojo',
      hex: '#C62828',
      stock: 2,
      vendidas: 40),
  StockConVentas(
      apliqueId: 1,
      aplique: _grande,
      colorId: 2,
      color: 'Blanco',
      hex: '#FFFFFF',
      stock: 5,
      vendidas: 24),
  StockConVentas(
      apliqueId: 1,
      aplique: _grande,
      colorId: 3,
      color: 'Rosado',
      hex: '#F48FB1',
      stock: 0,
      vendidas: 9),
  StockConVentas(
      apliqueId: 2,
      aplique: _mariposa,
      colorId: 6,
      color: 'Negro',
      hex: '#212121',
      stock: 3,
      vendidas: 12),
  StockConVentas(
      apliqueId: 3,
      aplique: 'Corazón Raso 5x5 - Bolsa x100 und',
      colorId: 1,
      color: 'Rojo',
      hex: '#C62828',
      stock: 60,
      vendidas: 8),
];

/// Sucursal nueva: no vendió nada en la ventana, se estima con las otras.
const _sinHistorial = [
  StockConVentas(
      apliqueId: 1,
      aplique: _grande,
      colorId: 1,
      color: 'Rojo',
      hex: '#C62828',
      stock: 4,
      vendidas: 0,
      vendidasOtras: 28),
  StockConVentas(
      apliqueId: 1,
      aplique: _grande,
      colorId: 2,
      color: 'Blanco',
      hex: '#FFFFFF',
      stock: 10,
      vendidas: 0,
      vendidasOtras: 12),
  StockConVentas(
      apliqueId: 2,
      aplique: _mariposa,
      colorId: 6,
      color: 'Negro',
      hex: '#212121',
      stock: 20,
      vendidas: 0,
      vendidasOtras: 6),
];

/// `/inventario` y `/inventario/:idsucursal`.
void capturasDeInventario(
  Dispositivo d, {
  bool todosLosEstados = false,
  Set<String> omitidas = const {},
}) {
  /// El SucursalesBloc es global en la app (main.dart).
  SucursalesBloc sucursales() {
    final bloc = SucursalesBloc(
      sucursalesRepository: FakeSucursalesRepository(sucursales: [
        Sucursal(id: 1, nombre: 'Ramada'),
        Sucursal(id: 2, nombre: 'Shopping Miami Feria Barrio Lindo'),
      ]),
    );
    addTearDown(bloc.close);
    return bloc;
  }

  Future<void> montarInventario(WidgetTester tester,
      List<StockConVentas> inventario, int idsucursal) async {
    final cubit = InventarioCubit(
      apliquesRepository:
          FakeApliquesRepository(inventarioConVentas: inventario),
      idsucursal: idsucursal,
      // Las ventas se miran hasta hoy: se fija
      hoy: () => DateTime(2026, 10, 15),
    );
    addTearDown(cubit.close);
    await d.montar(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sucursales()),
          BlocProvider.value(value: cubit),
        ],
        child: InventarioScreen(idsucursal: idsucursal),
      ),
    );
  }

  testWidgets('elegir la sucursal',
      skip: omitidas.contains('inventario_sucursales'), (tester) async {
    await d.montar(
      tester,
      BlocProvider.value(
        value: sucursales(),
        child: const InventarioSucursalesScreen(),
      ),
    );

    await d.comparar('inventario_sucursales');
  });

  testWidgets('faltantes de la sucursal', skip: omitidas.contains('inventario'),
      (tester) async {
    await montarInventario(tester, _ramada, 1);

    await d.comparar('inventario');
  });

  if (todosLosEstados) {
    testWidgets('todos: también lo que alcanza',
        skip: omitidas.contains('inventario_todos'), (tester) async {
      await montarInventario(tester, _ramada, 1);
      await tester.tap(find.textContaining('Todos').hitTestable());
      await tester.pumpAndSettle();

      await d.comparar('inventario_todos');
    });

    testWidgets('sucursal sin ventas propias: se estima con las otras',
        skip: omitidas.contains('inventario_estimado'), (tester) async {
      await montarInventario(tester, _sinHistorial, 2);

      await d.comparar('inventario_estimado');
    });
  }
}
