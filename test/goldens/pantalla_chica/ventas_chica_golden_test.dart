@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import 'chica_helpers.dart';

// `/ventas/:idsucursal`, `/det_ventas/:idventa` y `/det_venta/:idsucursal`.
void main() {
  /// Las tablas de telas (5 columnas) no entran en 360 dp con letra grande ni
  /// con las columnas al mínimo: en vez de recortar la columna de borrar se
  /// desplazan de costado (TablaDesplazable), por eso la captura se ve
  /// cortada a la derecha. Que entren enteras pide rediseñar la pantalla
  /// (una lista en vez de la tabla).
  void esperarTablaDesplazable(WidgetTester tester) {
    final tabla = tester.state<ScrollableState>(find.descendant(
      of: find.byType(TablaDesplazable),
      matching: find.byType(Scrollable),
    ));
    expect(tabla.position.maxScrollExtent, greaterThan(0));
  }

  Venta venta(int id, DateTime fecha, double total, double ganancias,
          double descuento) =>
      Venta(
        id: id,
        fecha: fecha,
        total: total,
        ganancias: ganancias,
        descuento: descuento,
        idsucursales: 1,
      );

  testWidgets('ventas de la sucursal, una por día', (tester) async {
    final bloc = VentasBloc(
      ventasRepository: FakeVentasRepository(ventas: [
        venta(6, DateTime(2026, 10, 10), 1250, 430, 20),
        venta(5, DateTime(2026, 10, 9), 870.5, 290, 0),
        venta(4, DateTime(2026, 10, 8), 2310, 815, 50),
        venta(3, DateTime(2026, 10, 6), 640, 210, 0),
        venta(2, DateTime(2026, 10, 3), 1580, 520, 10),
      ]),
      idsucursal: 1,
    );
    addTearDown(bloc.close);
    await montarChica(
      tester,
      BlocProvider.value(
        value: bloc,
        child: const VentasScreen(idsucursal: 1),
      ),
    );

    await compararChica('ventas');
  });

  testWidgets('líneas de la venta del día con total y descuento',
      (tester) async {
    final ventaBloc = VentaBloc(
      ventasRepository: FakeVentasRepository(
        venta: venta(7, DateTime(2026, 10, 10), 12895, 4307, 150),
      ),
      id: 7,
    );
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
        DetalleVenta(
          id: 3,
          nombre: 'Gabardina',
          precio: 24.5,
          cantidad: 150,
          total: 3675,
          ganancias: 975,
          idtelas: 3,
        ),
        DetalleVenta(
          id: 4,
          nombre: 'Lino Rústico Importado',
          precio: 1100,
          cantidad: 8,
          total: 8800,
          ganancias: 3200,
          idtelas: 4,
        ),
      ]),
      ventaActualizada: ventaBloc.mostrarVenta,
      idventa: 7,
    );
    addTearDown(ventaBloc.close);
    addTearDown(detalleBloc.close);
    await montarChica(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: ventaBloc),
          BlocProvider.value(value: detalleBloc),
        ],
        child: const DetVentas(idventa: 7),
      ),
    );

    esperarTablaDesplazable(tester);
    await compararChica('det_ventas');
  });

  testWidgets('registro de la venta con líneas en el carrito', (tester) async {
    final telasBloc = TelasBloc(
      telasRepository: FakeTelasRepository(telas: [
        Tela(id: 1, nombre: 'Lino', precxmen: 35, precxcompra: 22),
        Tela(id: 3, nombre: 'Gabardina', precxmen: 28, precxcompra: 18),
        Tela(id: 4, nombre: 'Lino Rústico', precxmen: 32, precxcompra: 20),
      ]),
      idsucursal: 1,
    );
    final cubit = DetalleVentaFormCubit(
      ventasRepository: FakeVentasRepository(),
      idsucursal: 1,
    )..onFechaChanged(DateTime(2026, 10, 10));
    addTearDown(cubit.close);
    addTearDown(telasBloc.close);
    await montarChica(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: telasBloc),
        ],
        child: const DetVenta(),
      ),
    );

    Finder campo(String label) => find.widgetWithText(TextFormField, label);

    Future<void> anadir(String tela, String precio, String cantidad) async {
      await tester.ensureVisible(find.byType(DropdownMenu<Tela>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownMenu<Tela>));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, tela).last);
      await tester.pumpAndSettle();
      await tester.enterText(campo('Precio'), precio);
      await tester.enterText(campo('Cantidad'), cantidad);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Añadir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Añadir'));
      await tester.pumpAndSettle();
    }

    await anadir('Lino Rústico', '1100', '8');
    await anadir('Gabardina', '24.5', '150');
    await tester.ensureVisible(find.byType(DropdownMenu<Tela>));
    await tester.pumpAndSettle();

    esperarTablaDesplazable(tester);
    await compararChica('det_venta');
  });
}
