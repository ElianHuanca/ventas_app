@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../../helpers/fake_repositories.dart';
import 'chica_helpers.dart';

// `/venta-apliques`, `/venta-apliques/:idsucursal`,
// `/venta-apliques/registro/:idsucursal` y `/venta-apliques/detalle/:idventa`.
void main() {
  testWidgets('elegir la sucursal', (tester) async {
    final bloc = SucursalesBloc(
      sucursalesRepository: FakeSucursalesRepository(sucursales: [
        Sucursal(id: 1, nombre: 'Casa Central'),
        Sucursal(id: 2, nombre: 'Mercado Campesino'),
        Sucursal(id: 3, nombre: 'La Ramada'),
      ]),
    );
    addTearDown(bloc.close);
    await montarChica(
      tester,
      BlocProvider.value(
        value: bloc,
        child: const VentaApliquesSucursalesScreen(),
      ),
    );

    await compararChica('venta_apliques_sucursales');
  });

  testWidgets('ventas de la sucursal, una por día', (tester) async {
    final bloc = VentasApliquesBloc(
      ventasApliquesRepository: FakeVentasApliquesRepository(ventas: [
        VentaAplique(id: 48, fecha: DateTime(2026, 10, 10)),
        VentaAplique(id: 47, fecha: DateTime(2026, 10, 9)),
        VentaAplique(id: 45, fecha: DateTime(2026, 10, 7)),
        VentaAplique(id: 44, fecha: DateTime(2026, 10, 6)),
        VentaAplique(id: 41, fecha: DateTime(2026, 10, 3)),
      ]),
      idsucursal: 1,
    );
    addTearDown(bloc.close);
    await montarChica(
      tester,
      BlocProvider.value(
        value: bloc,
        child: const VentasApliquesScreen(idsucursal: 1),
      ),
    );

    await compararChica('ventas_apliques');
  });

  testWidgets('registro de la venta con líneas en el carrito', (tester) async {
    final apliquesBloc = ApliquesBloc(
      apliquesRepository: FakeApliquesRepository(
        apliques: [
          Aplique(id: 1, nombre: 'Flor bordada 10x10', costoFabricacion: 12),
          Aplique(id: 2, nombre: 'Corazón 5x5', costoFabricacion: 3),
          Aplique(id: 3, nombre: 'Mariposa 8x6', costoFabricacion: 7),
        ],
        stock: const [
          StockAplique(
              apliqueId: 1,
              colorId: 5,
              colorNombre: 'Rojo',
              hex: '#D32F2F',
              stock: 12),
          StockAplique(
              apliqueId: 1,
              colorId: 8,
              colorNombre: 'Azul marino',
              hex: '#1A237E',
              stock: 2),
          StockAplique(
              apliqueId: 2,
              colorId: 9,
              colorNombre: 'Rosado',
              hex: '#F48FB1',
              stock: 15),
        ],
      ),
      idsucursal: 1,
    );
    addTearDown(apliquesBloc.close);
    final cubit = VentaApliquesFormCubit(
      ventasApliquesRepository: FakeVentasApliquesRepository(),
      idsucursal: 1,
    );
    addTearDown(cubit.close);
    await montarChica(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: apliquesBloc),
          BlocProvider.value(value: cubit),
        ],
        child: VentaApliquesScreen(),
      ),
    );

    Future<void> elegir<T>(String opcion) async {
      await tester.ensureVisible(find.byType(DropdownMenu<T>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenu<T>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(opcion).last);
      await tester.pumpAndSettle();
    }

    Finder campo(String label) => find.widgetWithText(TextFormField, label);

    Future<void> anadir(
        String aplique, String color, String cantidad, String precio) async {
      await elegir<Aplique>(aplique);
      await elegir<StockAplique>(color);
      await tester.enterText(campo('Cantidad'), cantidad);
      await tester.enterText(campo('Precio'), precio);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Añadir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
    }

    await anadir('Flor bordada 10x10', 'Rojo (stock: 12.0)', '3', '25');
    await anadir('Corazón 5x5', 'Rosado (stock: 15.0)', '6', '8');
    await anadir('Flor bordada 10x10', 'Azul marino (stock: 2.0)', '2', '25');
    await tester.ensureVisible(find.byType(DropdownMenu<Aplique>));
    await tester.pumpAndSettle();

    await compararChica('venta_apliques');
  });

  testWidgets('líneas de la venta del día', (tester) async {
    final cubit = DetalleVentaApliquesCubit(
      ventasApliquesRepository: FakeVentasApliquesRepository(detalle: const [
        DetalleVentaAplique(
          id: 1,
          nombre: 'Flor bordada 10x10 (Rojo)',
          cantidad: 3,
          precio: 25,
          total: 75,
        ),
        DetalleVentaAplique(
          id: 2,
          nombre: 'Flor bordada 10x10 (Azul marino)',
          cantidad: 2,
          precio: 25,
          total: 50,
        ),
        DetalleVentaAplique(
          id: 3,
          nombre: 'Mariposa lentejuela 8x6 (Verde esmeralda)',
          cantidad: 120,
          precio: 18.5,
          total: 2220,
        ),
      ]),
      idventa: 48,
    );
    addTearDown(cubit.close);
    await montarChica(
      tester,
      BlocProvider.value(
        value: cubit,
        child: VentaApliquesDetalleScreen(
          idventa: 48,
          fecha: DateTime(2026, 10, 10),
        ),
      ),
    );

    await compararChica('venta_apliques_detalle');
  });
}
