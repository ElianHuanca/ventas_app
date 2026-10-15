@Tags(['golden'])
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../../helpers/fake_repositories.dart';
import 'chica_helpers.dart';

// `/inventario` y `/inventario/:idsucursal`.
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

  testWidgets('elegir la sucursal', (tester) async {
    await montarChica(
      tester,
      BlocProvider.value(
        value: sucursales(),
        child: const InventarioSucursalesScreen(),
      ),
    );

    await compararChica('inventario_sucursales');
  });

  testWidgets('faltantes de la sucursal', (tester) async {
    const grande = 'Flor Petalo Suizo Grande - Bolsa x100 und';
    final cubit = InventarioCubit(
      apliquesRepository: FakeApliquesRepository(inventarioConVentas: const [
        StockConVentas(
            apliqueId: 1,
            aplique: grande,
            colorId: 1,
            color: 'Rojo',
            hex: '#C62828',
            stock: 2,
            vendidas: 40),
        StockConVentas(
            apliqueId: 1,
            aplique: grande,
            colorId: 2,
            color: 'Blanco',
            hex: '#FFFFFF',
            stock: 5,
            vendidas: 24),
        StockConVentas(
            apliqueId: 1,
            aplique: grande,
            colorId: 3,
            color: 'Rosado',
            hex: '#F48FB1',
            stock: 0,
            vendidas: 9),
        StockConVentas(
            apliqueId: 2,
            aplique: 'Mariposa Lentejuela 8x6 - Bolsa x50 und',
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
      ]),
      idsucursal: 1,
      // Las ventas se miran hasta hoy: se fija
      hoy: () => DateTime(2026, 10, 15),
    );
    addTearDown(cubit.close);
    await montarChica(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sucursales()),
          BlocProvider.value(value: cubit),
        ],
        child: const InventarioScreen(idsucursal: 1),
      ),
    );

    await compararChica('inventario');
  });
}
