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

// `/fabricacion`, `/fabricacion/:idsucursal`,
// `/fabricacion/registro/:idsucursal` y `/fabricacion/detalle/:idproduccion`.
void main() {
  testWidgets('elegir la sucursal', (tester) async {
    final bloc = SucursalesBloc(
      sucursalesRepository: FakeSucursalesRepository(sucursales: [
        Sucursal(id: 1, nombre: 'Central'),
        Sucursal(id: 2, nombre: 'Norte'),
        Sucursal(id: 3, nombre: 'Mercado Campesino'),
      ]),
    );
    addTearDown(bloc.close);
    await montarChica(
      tester,
      BlocProvider.value(
        value: bloc,
        child: const FabricacionSucursalesScreen(),
      ),
    );

    await compararChica('fabricacion_sucursales');
  });

  testWidgets('producciones de la sucursal, una por día', (tester) async {
    final bloc = ProduccionesBloc(
      apliquesRepository: FakeApliquesRepository(producciones: [
        ProduccionCabecera(id: 14, fecha: DateTime(2026, 10, 3)),
        ProduccionCabecera(id: 12, fecha: DateTime(2026, 10, 1)),
        ProduccionCabecera(id: 9, fecha: DateTime(2026, 9, 26)),
        ProduccionCabecera(id: 5, fecha: DateTime(2026, 9, 15)),
        ProduccionCabecera(id: 2, fecha: DateTime(2026, 8, 30)),
      ]),
      idsucursal: 1,
    );
    addTearDown(bloc.close);
    await montarChica(
      tester,
      BlocProvider.value(
        value: bloc,
        child: const ProduccionesScreen(idsucursal: 1),
      ),
    );

    await compararChica('producciones');
  });

  testWidgets('registro de la producción con líneas añadidas', (tester) async {
    final cubit = ProduccionFormCubit(
      apliquesRepository: FakeApliquesRepository(
        apliques: [
          Aplique(id: 1, nombre: 'Flor bordada 10x10', costoFabricacion: 12.5),
          Aplique(id: 2, nombre: 'Corazón 5x5', costoFabricacion: 4),
          Aplique(
              id: 3, nombre: 'Mariposa lentejuela 8x6', costoFabricacion: 9.5),
        ],
        colores: const [
          ColorItem(id: 1, nombre: 'Rojo', hex: '#C62828', vinculado: true),
          ColorItem(
              id: 2, nombre: 'Azul marino', hex: '#1A237E', vinculado: true),
          ColorItem(id: 4, nombre: 'Dorado', hex: '#D4AF37', vinculado: true),
        ],
        stock: const [
          StockAplique(
              apliqueId: 1,
              colorId: 1,
              colorNombre: 'Rojo',
              hex: '#C62828',
              stock: 24),
          StockAplique(
              apliqueId: 2,
              colorId: 2,
              colorNombre: 'Azul marino',
              hex: '#1A237E',
              stock: 3),
        ],
      ),
      idsucursal: 1,
    );
    addTearDown(cubit.close);
    // La fecha arranca en DateTime.now(): se fija para que la captura no
    // cambie de un día a otro
    cubit.onFechaChanged(DateTime(2026, 10, 3));
    await montarChica(
      tester,
      BlocProvider.value(value: cubit, child: const ProduccionScreen()),
    );

    Future<void> elegir<T>(String opcion) async {
      await tester.ensureVisible(find.byType(DropdownMenu<T>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenu<T>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(opcion).last);
      await tester.pumpAndSettle();
    }

    Future<void> anadir(String aplique, String color, String cantidad) async {
      await elegir<Aplique>(aplique);
      await elegir<ColorItem>(color);
      await tester.enterText(find.byType(TextFormField), cantidad);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Añadir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
    }

    await anadir('Corazón 5x5', 'Azul marino (stock: 3.0)', '6');
    await anadir('Flor bordada 10x10', 'Rojo (stock: 24.0)', '12');
    await tester.ensureVisible(find.byType(DropdownMenu<Aplique>));
    await tester.pumpAndSettle();

    await compararChica('produccion');
  });

  testWidgets('líneas de la producción del día', (tester) async {
    final cubit = DetalleProduccionCubit(
      apliquesRepository: FakeApliquesRepository(detalleProduccion: const [
        Produccion(
          id: 31,
          fecha: '2026-10-03',
          sucursalNombre: 'Central',
          apliqueNombre: 'Flor bordada 10x10',
          colorNombre: 'Rojo',
          hex: '#C62828',
          cantidad: 24,
        ),
        Produccion(
          id: 32,
          fecha: '2026-10-03',
          sucursalNombre: 'Central',
          apliqueNombre: 'Flor bordada 10x10',
          colorNombre: 'Azul marino',
          hex: '#1A237E',
          cantidad: 12,
        ),
        Produccion(
          id: 33,
          fecha: '2026-10-03',
          sucursalNombre: 'Central',
          apliqueNombre: 'Mariposa lentejuela 8x6',
          colorNombre: 'Verde esmeralda',
          hex: '#2E7D32',
          cantidad: 150,
        ),
      ]),
      idproduccion: 14,
    );
    addTearDown(cubit.close);
    await montarChica(
      tester,
      BlocProvider.value(
        value: cubit,
        child: const ProduccionDetalleScreen(idproduccion: 14),
      ),
    );

    await compararChica('produccion_detalle');
  });
}
