import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/presentation/screens/screens.dart';

import '../helpers/fake_repositories.dart';
import 'accesibilidad_helpers.dart';

void main() {
  final venta = Venta(
    id: 7,
    fecha: DateTime(2026, 10, 10),
    total: 362.5,
    ganancias: 125.5,
    descuento: 15,
    idsucursales: 1,
  );

  group('/ventas/:idsucursal (VentasScreen)', () {
    verificarGuias('ventas de la sucursal, una por día', (tester) {
      final bloc = VentasBloc(
        ventasRepository: FakeVentasRepository(ventas: [
          venta,
          Venta(
            id: 6,
            fecha: DateTime(2026, 10, 9),
            total: 870.5,
            ganancias: 290,
            descuento: 0,
            idsucursales: 1,
          ),
        ]),
        idsucursal: 1,
      );
      addTearDown(bloc.close);
      return montarPantalla(
        tester,
        BlocProvider.value(
          value: bloc,
          child: const VentasScreen(idsucursal: 1),
        ),
      );
    });
  });

  group('/det_ventas/:idventa (DetVentas)', () {
    verificarGuias('líneas de la venta con total y descuento', (tester) {
      // Los dos blocs cableados como en app_router
      final ventaBloc = VentaBloc(
          ventasRepository: FakeVentasRepository(venta: venta), id: 7);
      final detalleBloc = DetalleVentasBloc(
        detalleVentasRepository: FakeDetalleVentasRepository(detalles: const [
          DetalleVenta(
            id: 1,
            nombre: 'Lino',
            precio: 35,
            cantidad: 3.5,
            total: 122.5,
            ganancias: 45.5,
            idtelas: 1,
          ),
          DetalleVenta(
            id: 2,
            nombre: 'Seda',
            precio: 60,
            cantidad: 4,
            total: 240,
            ganancias: 80,
            idtelas: 2,
          ),
        ]),
        updateVenta: ventaBloc.actualizarVenta,
        idventa: 7,
      );
      addTearDown(ventaBloc.close);
      addTearDown(detalleBloc.close);
      return montarPantalla(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: ventaBloc),
            BlocProvider.value(value: detalleBloc),
          ],
          child: const DetVentas(idventa: 7),
        ),
      );
    });
  });

  group('/det_venta/:idsucursal (DetVenta)', () {
    Future<void> montar(WidgetTester tester) {
      final cubit = DetalleVentaFormCubit(
        ventasRepository: FakeVentasRepository(),
        detalleVentasRepository: FakeDetalleVentasRepository(),
        idsucursal: 1,
      )..onFechaChanged(DateTime(2026, 10, 10));
      final telasBloc = TelasBloc(
        telasRepository: FakeTelasRepository(telas: [
          Tela(id: 1, nombre: 'Lino', precxmen: 35, precxcompra: 22),
          Tela(id: 3, nombre: 'Gabardina', precxmen: 28, precxcompra: 18),
        ]),
        idsucursal: 1,
      );
      addTearDown(cubit.close);
      addTearDown(telasBloc.close);
      return montarPantalla(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: telasBloc),
          ],
          child: DetVenta(),
        ),
      );
    }

    Finder campo(String label) => find.widgetWithText(TextFormField, label);

    Future<void> anadir(WidgetTester tester, String tela, String precio,
        String cantidad) async {
      await tester.tap(find.byType(DropdownMenu<Tela>));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, tela).last);
      await tester.pumpAndSettle();
      await tester.enterText(campo('Precio'), precio);
      await tester.enterText(campo('Cantidad'), cantidad);
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
    }

    verificarGuias('formulario vacío', montar);

    verificarGuias('con líneas en el carrito', (tester) async {
      await montar(tester);
      await anadir(tester, 'Lino', '35', '2');
      await anadir(tester, 'Gabardina', '24.5', '10');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    });
  });
}
