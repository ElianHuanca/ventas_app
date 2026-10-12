import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../helpers/fake_repositories.dart';
import 'accesibilidad_helpers.dart';

void main() {
  final apliques = [
    Aplique(id: 1, nombre: 'Flor bordada 10x10', costoFabricacion: 12.5),
    Aplique(id: 2, nombre: 'Corazón 5x5', costoFabricacion: 4),
  ];
  // El fake devuelve estos colores para cualquier aplique; la pantalla solo
  // ofrece los vinculados.
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo', hex: '#C62828', vinculado: true),
    ColorItem(id: 2, nombre: 'Azul marino', hex: '#1A237E', vinculado: true),
    ColorItem(id: 3, nombre: 'Blanco', hex: '#FFFFFF', vinculado: false),
  ];
  const stock = [
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
  ];

  group('/fabricacion (FabricacionSucursalesScreen)', () {
    verificarGuias('una tarjeta por sucursal', (tester) {
      // El SucursalesBloc es global en la app (main.dart)
      final bloc = SucursalesBloc(
        sucursalesRepository: FakeSucursalesRepository(sucursales: [
          Sucursal(id: 1, nombre: 'Central'),
          Sucursal(id: 2, nombre: 'Norte'),
        ]),
      );
      addTearDown(bloc.close);
      return montarPantalla(
        tester,
        BlocProvider.value(
          value: bloc,
          child: const FabricacionSucursalesScreen(),
        ),
      );
    });
  });

  group('/fabricacion/:idsucursal (ProduccionesScreen)', () {
    verificarGuias('una tarjeta por día de fabricación', (tester) {
      final bloc = ProduccionesBloc(
        apliquesRepository: FakeApliquesRepository(producciones: [
          ProduccionCabecera(id: 14, fecha: DateTime(2026, 10, 3)),
          ProduccionCabecera(id: 12, fecha: DateTime(2026, 10, 1)),
        ]),
        idsucursal: 1,
      );
      addTearDown(bloc.close);
      return montarPantalla(
        tester,
        BlocProvider.value(
          value: bloc,
          child: const ProduccionesScreen(idsucursal: 1),
        ),
      );
    });
  });

  group('/fabricacion/registro/:idsucursal (ProduccionScreen)', () {
    Future<void> montar(WidgetTester tester) {
      final cubit = ProduccionFormCubit(
        apliquesRepository: FakeApliquesRepository(
          apliques: apliques,
          colores: colores,
          stock: stock,
        ),
        idsucursal: 1,
      );
      addTearDown(cubit.close);
      // La fecha arranca en DateTime.now(): se fija
      cubit.onFechaChanged(DateTime(2026, 10, 3));
      return montarPantalla(
        tester,
        BlocProvider.value(value: cubit, child: ProduccionScreen()),
      );
    }

    Future<void> elegir<T>(WidgetTester tester, String opcion) async {
      await tester.tap(find.byType(DropdownMenu<T>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(opcion).last);
      await tester.pumpAndSettle();
    }

    Future<void> anadir(WidgetTester tester, String aplique, String color,
        String cantidad) async {
      await elegir<Aplique>(tester, aplique);
      await elegir<ColorItem>(tester, color);
      await tester.enterText(find.byType(TextFormField), cantidad);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
    }

    verificarGuias('formulario inicial', montar);

    verificarGuias('con líneas añadidas', (tester) async {
      await montar(tester);
      await anadir(tester, 'Corazón 5x5', 'Azul marino (stock: 3.0)', '6');
      await anadir(tester, 'Flor bordada 10x10', 'Rojo (stock: 24.0)', '12');
    });
  });

  group('/fabricacion/detalle/:idproduccion (ProduccionDetalleScreen)', () {
    verificarGuias('líneas de la producción del día', (tester) {
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
            apliqueNombre: 'Corazón 5x5',
            colorNombre: 'Dorado',
            hex: '#D4AF37',
            cantidad: 50,
          ),
        ]),
        idproduccion: 14,
      );
      addTearDown(cubit.close);
      return montarPantalla(
        tester,
        BlocProvider.value(
          value: cubit,
          child: const ProduccionDetalleScreen(idproduccion: 14),
        ),
      );
    });
  });
}
