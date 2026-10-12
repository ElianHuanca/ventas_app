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
    Aplique(id: 1, nombre: 'Flor bordada 10x10', costoFabricacion: 12),
    Aplique(id: 2, nombre: 'Corazón 5x5', costoFabricacion: 3),
  ];
  // Stock de la sucursal por aplique+color (solo colores vinculados)
  const stock = [
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
  ];

  group('/venta-apliques (VentaApliquesSucursalesScreen)', () {
    verificarGuias('una tarjeta por sucursal', (tester) {
      // El SucursalesBloc es global en la app (main.dart)
      final bloc = SucursalesBloc(
        sucursalesRepository: FakeSucursalesRepository(sucursales: [
          Sucursal(id: 1, nombre: 'Casa Central'),
          Sucursal(id: 2, nombre: 'Mercado Campesino'),
        ]),
      );
      addTearDown(bloc.close);
      return montarPantalla(
        tester,
        BlocProvider.value(
          value: bloc,
          child: const VentaApliquesSucursalesScreen(),
        ),
      );
    });
  });

  group('/venta-apliques/:idsucursal (VentasApliquesScreen)', () {
    verificarGuias('una tarjeta por día con ventas', (tester) {
      final bloc = VentasApliquesBloc(
        ventasApliquesRepository: FakeVentasApliquesRepository(ventas: [
          VentaAplique(id: 48, fecha: DateTime(2026, 10, 10)),
          VentaAplique(id: 47, fecha: DateTime(2026, 10, 9)),
        ]),
        idsucursal: 1,
      );
      addTearDown(bloc.close);
      return montarPantalla(
        tester,
        BlocProvider.value(
          value: bloc,
          child: const VentasApliquesScreen(idsucursal: 1),
        ),
      );
    });
  });

  group('/venta-apliques/registro/:idsucursal (VentaApliquesScreen)', () {
    Future<void> montar(WidgetTester tester) {
      final apliquesBloc = ApliquesBloc(
        apliquesRepository:
            FakeApliquesRepository(apliques: apliques, stock: stock),
        idsucursal: 1,
      );
      addTearDown(apliquesBloc.close);
      final cubit = VentaApliquesFormCubit(
        ventasApliquesRepository: FakeVentasApliquesRepository(),
        idsucursal: 1,
      );
      addTearDown(cubit.close);
      return montarPantalla(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: apliquesBloc),
            BlocProvider.value(value: cubit),
          ],
          child: VentaApliquesScreen(),
        ),
      );
    }

    Future<void> elegir<T>(WidgetTester tester, String opcion) async {
      await tester.tap(find.byType(DropdownMenu<T>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(opcion).last);
      await tester.pumpAndSettle();
    }

    Finder campo(String label) => find.widgetWithText(TextFormField, label);

    Future<void> anadir(WidgetTester tester, String aplique, String color,
        String cantidad, String precio) async {
      await elegir<Aplique>(tester, aplique);
      await elegir<StockAplique>(tester, color);
      await tester.enterText(campo('Cantidad'), cantidad);
      await tester.enterText(campo('Precio'), precio);
      await tester.ensureVisible(find.text('Añadir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
    }

    verificarGuias('formulario vacío', montar);

    verificarGuias('con líneas en el carrito', (tester) async {
      await montar(tester);
      await anadir(
          tester, 'Flor bordada 10x10', 'Rojo (stock: 12.0)', '3', '25');
      await anadir(tester, 'Corazón 5x5', 'Rosado (stock: 15.0)', '6', '8');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar'));
      await tester.pumpAndSettle();
    });
  });

  group('/venta-apliques/detalle/:idventa (VentaApliquesDetalleScreen)', () {
    verificarGuias('líneas de la venta con su total', (tester) {
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
            nombre: 'Corazón 5x5 (Rosado)',
            cantidad: 6,
            precio: 8,
            total: 48,
          ),
        ]),
        idventa: 48,
      );
      addTearDown(cubit.close);
      return montarPantalla(
        tester,
        BlocProvider.value(
          value: cubit,
          child: VentaApliquesDetalleScreen(
            idventa: 48,
            fecha: DateTime(2026, 10, 10),
          ),
        ),
      );
    });
  });
}
