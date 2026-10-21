import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../helpers/fake_repositories.dart';
import 'accesibilidad_helpers.dart';

const _grande = 'Flor Petalo Suizo Grande - Bolsa x100 und';
const _mariposa = 'Mariposa Lentejuela 8x6 - Bolsa x50 und';

/// Ramada: faltan Rojo, Blanco y Negro; Celeste no se vende y el corazón
/// alcanza.
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
      colorId: 4,
      color: 'Celeste',
      hex: '#81D4FA',
      stock: 12,
      vendidas: 0),
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

/// Sucursal nueva: no vendió nada, se estima con lo que venden las otras.
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
      apliqueId: 2,
      aplique: _mariposa,
      colorId: 6,
      color: 'Negro',
      hex: '#212121',
      stock: 1,
      vendidas: 0,
      vendidasOtras: 6),
];

void main() {
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

  group('/inventario (InventarioSucursalesScreen)', () {
    verificarGuias(
      'una tarjeta por sucursal',
      (tester) => montarPantalla(
        tester,
        BlocProvider.value(
          value: sucursales(),
          child: const InventarioSucursalesScreen(),
        ),
      ),
    );
  });

  group('/inventario/:idsucursal (InventarioScreen)', () {
    Future<void> montar(
      WidgetTester tester,
      List<StockConVentas> inventario, {
      int idsucursal = 1,
    }) {
      final cubit = InventarioCubit(
        apliquesRepository:
            FakeApliquesRepository(inventarioConVentas: inventario),
        idsucursal: idsucursal,
        // Las ventas se miran hasta hoy: se fija
        hoy: () => DateTime(2026, 10, 15),
      );
      addTearDown(cubit.close);
      return montarPantalla(
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

    verificarGuias('faltantes', (tester) => montar(tester, _ramada));

    verificarGuias('todos', (tester) async {
      await montar(tester, _ramada);
      await tester.tap(find.textContaining('Todos').hitTestable());
      await tester.pumpAndSettle();
    });

    verificarGuias('estimada con las otras sucursales',
        (tester) => montar(tester, _sinHistorial, idsucursal: 2));
  });
}
