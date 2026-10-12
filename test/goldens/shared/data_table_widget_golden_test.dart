@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/widgets/data_table_widget.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';

import '../golden_helpers.dart';

void main() {
  const encabezados = ['Tela', 'Cantidad', 'Precio', 'Total', 'Accion'];
  const lineas = [
    DetalleVenta(
        id: 1,
        nombre: 'Lino',
        precio: 45,
        cantidad: 2.5,
        total: 112.5,
        ganancias: 37.5,
        idtelas: 1),
    DetalleVenta(
        id: 2,
        nombre: 'Seda',
        precio: 60,
        cantidad: 1,
        total: 60,
        ganancias: 20,
        idtelas: 2),
    DetalleVenta(
        id: 3,
        nombre: 'Gabardina',
        precio: 35,
        cantidad: 4,
        total: 140,
        ganancias: 40,
        idtelas: 3),
  ];

  /// Las líneas de una venta del día, como en DetVentasScreen.
  Future<void> montar(WidgetTester tester) => montarParaCaptura(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ListView(
              children: [
                dataTableWidget(
                    encabezados, context, lineas, 312.5, 97.5, 12.5, (_) {}),
              ],
            ),
          ),
        ),
      );

  testWidgets('líneas de la venta con total y descuento', (tester) async {
    await montar(tester);

    expect(find.text('Descuento'), findsOneWidget);
    await compararCaptura('data_table_widget_con_lineas');
  });

  testWidgets('borrar una línea pide confirmación', (tester) async {
    await montar(tester);

    await tester.tap(find.byIcon(Icons.delete_forever_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar Eliminación'), findsOneWidget);
    await compararCaptura('data_table_widget_confirmar_borrado');
  });
}
