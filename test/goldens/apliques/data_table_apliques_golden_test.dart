@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/presentation/widgets/data_table_apliques.dart';

import '../golden_helpers.dart';

void main() {
  final lineas = [
    {
      'idapliques': 1,
      'idcolor': 1,
      'nombre': 'Flor bordada 10x10 (Rojo)',
      'cantidad': 2.0,
      'precio': 25.0,
      'total': 50.0,
      'ganancias': 25.0,
    },
    {
      'idapliques': 2,
      'idcolor': 2,
      'nombre': 'Corazón 5x5 (Azul marino)',
      'cantidad': 6.0,
      'precio': 8.0,
      'total': 48.0,
      'ganancias': 24.0,
    },
  ];

  /// Como en la venta de apliques: la tabla va dentro del ListView de la
  /// pantalla, a todo el ancho del teléfono.
  Future<void> montar(
    WidgetTester tester, {
    required List<Map<String, dynamic>> listbody,
    required double total,
  }) =>
      montarParaCaptura(
        tester,
        Scaffold(
          body: ListView(
            children: [
              DataTableApliques(
                listbody: listbody,
                total: total,
                onTap: (_, __, ___, ____) {},
              ),
            ],
          ),
        ),
      );

  testWidgets('líneas de la venta con su total', (tester) async {
    await montar(tester, listbody: lineas, total: 98);

    await compararCaptura('data_table_apliques_lineas');
  });

  testWidgets('un nombre largo como los de producción se lee entero',
      (tester) async {
    const largo = 'Flor Petalo Suizo Grande - Bolsa x100 und (Verde esmeralda)';
    await montar(
      tester,
      listbody: [
        {
          'idapliques': 3,
          'idcolor': 4,
          'nombre': largo,
          'cantidad': 12.0,
          'precio': 150.0,
          'total': 1800.0,
          'ganancias': 600.0,
        },
        ...lineas,
      ],
      total: 1898,
    );

    final nombre = tester.renderObject<RenderParagraph>(find.text(largo));
    expect(
      nombre.getMaxIntrinsicHeight(nombre.size.width),
      lessThanOrEqualTo(nombre.size.height),
      reason: 'el nombre no entra en la fila y se corta',
    );
    await compararCaptura('data_table_apliques_nombre_largo');
  });

  testWidgets('sin líneas: solo la fila de total en 0', (tester) async {
    await montar(tester, listbody: const [], total: 0);

    await compararCaptura('data_table_apliques_vacia');
  });
}
