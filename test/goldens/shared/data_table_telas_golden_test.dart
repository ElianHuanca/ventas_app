@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/widgets/data_table_telas.dart';

import '../golden_helpers.dart';

void main() {
  const encabezados = ['Nombre', 'Cantidad', 'Precio', 'Total', ''];

  /// El carrito del formulario de venta de telas (DetVentaScreen).
  Widget carrito(List<Map<String, dynamic>> lineas, double total) => Scaffold(
        body: ListView(
          children: [
            DataTableMapTelas(
              listheader: encabezados,
              listbody: lineas,
              total: total,
              onTap: (_, __, ___) {},
            ),
          ],
        ),
      );

  testWidgets('con líneas y la fila de total', (tester) async {
    await montarParaCaptura(
      tester,
      carrito([
        {
          'idtelas': 1,
          'nombre': 'Lino',
          'cantidad': 2.5,
          'precio': 45.0,
          'total': 112.5,
          'ganancias': 37.5,
        },
        {
          'idtelas': 2,
          'nombre': 'Seda',
          'cantidad': 1.0,
          'precio': 60.0,
          'total': 60.0,
          'ganancias': 20.0,
        },
        {
          'idtelas': 3,
          'nombre': 'Gabardina',
          'cantidad': 4.0,
          'precio': 35.0,
          'total': 140.0,
          'ganancias': 40.0,
        },
      ], 312.5),
    );

    expect(find.text('312.5 Bs'), findsOneWidget);
    await compararCaptura('data_table_telas_con_lineas');
  });

  testWidgets('vacía: solo la fila de total en 0', (tester) async {
    await montarParaCaptura(tester, carrito(const [], 0));

    expect(find.text('0.0 Bs'), findsOneWidget);
    await compararCaptura('data_table_telas_vacia');
  });
}
