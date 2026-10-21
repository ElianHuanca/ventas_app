@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

void main() {
  // Total de la venta = suma de las líneas (895 Bs); el descuento se guarda
  // aparte, como en la tabla `ventas`.
  final venta = Venta(
    id: 7,
    fecha: DateTime(2026, 10, 10),
    total: 895,
    ganancias: 307,
    descuento: 15,
    idsucursales: 1,
  );

  const detalles = [
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
      cantidad: 15,
      total: 367.5,
      ganancias: 97.5,
      idtelas: 3,
    ),
    DetalleVenta(
      id: 4,
      nombre: 'Lino Rústico',
      precio: 33,
      cantidad: 5,
      total: 165,
      ganancias: 84,
      idtelas: 4,
    ),
  ];

  /// Monta el detalle con sus dos blocs, cableados como en app_router.
  Future<void> montar(
    WidgetTester tester,
    List<DetalleVenta> detalles,
  ) async {
    final ventasRepo = FakeVentasRepository(venta: venta);
    final detalleRepo = FakeDetalleVentasRepository(detalles: detalles);
    final ventaBloc = VentaBloc(ventasRepository: ventasRepo, id: 7);
    final detalleBloc = DetalleVentasBloc(
      detalleVentasRepository: detalleRepo,
      ventaActualizada: ventaBloc.mostrarVenta,
      idventa: 7,
    );
    addTearDown(ventaBloc.close);
    addTearDown(detalleBloc.close);
    await montarParaCaptura(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: ventaBloc),
          BlocProvider.value(value: detalleBloc),
        ],
        child: const DetVentas(idventa: 7),
      ),
    );
  }

  testWidgets('líneas de la venta del día con total y descuento',
      (tester) async {
    await montar(tester, detalles);

    await compararCaptura('det_ventas_lineas');
  });

  testWidgets('venta sin líneas', (tester) async {
    await montar(tester, const []);

    await compararCaptura('det_ventas_vacia');
  });

  testWidgets('confirmación antes de borrar una línea', (tester) async {
    await montar(tester, detalles);

    await tester.tap(find.byIcon(Icons.delete_forever_rounded).first);
    await tester.pumpAndSettle();

    await compararCaptura('det_ventas_confirmar_eliminacion');
  });
}
