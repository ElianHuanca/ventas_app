@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';

import '../golden_helpers.dart';

void main() {
  testWidgets('cabecera con título, subtítulo, botón + y la tabla',
      (tester) async {
    await montarParaCaptura(
      tester,
      Builder(
        builder: (context) => Screen2(
          title: 'Ventas',
          subtitle: 'Sucursal Central',
          dataTable: dataTableWidget(
            const ['Tela', 'Cantidad', 'Precio', 'Total', 'Accion'],
            context,
            const [
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
            ],
            172.5,
            57.5,
            0,
            (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Sucursal Central'), findsOneWidget);
    await compararCaptura('screen2_con_tabla');
  });
}
