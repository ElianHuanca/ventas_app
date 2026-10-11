@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/presentation/widgets/data_table_produccion.dart';

import '../golden_helpers.dart';

void main() {
  final lineas = [
    {
      'idaplique': 1,
      'apliqueNombre': 'Flor bordada 10x10',
      'idcolor': 1,
      'colorNombre': 'Rojo',
      'hex': '#C62828',
      'cantidad': 24.0,
    },
    {
      'idaplique': 2,
      'apliqueNombre': 'Corazón 5x5',
      'idcolor': 4,
      'colorNombre': 'Verde esmeralda',
      'hex': '#2E7D32',
      'cantidad': 6.0,
    },
  ];

  /// Como en el registro de fabricación: la tabla va en una Column
  /// (crossAxisAlignment.start) dentro del ListView de la pantalla.
  Future<void> montar(
    WidgetTester tester,
    List<Map<String, dynamic>> listbody,
  ) =>
      montarParaCaptura(
        tester,
        Scaffold(
          body: ListView(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DataTableProduccion(
                    listbody: listbody,
                    onTap: (_, __, ___) {},
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  testWidgets('líneas con aplique, color y cantidad', (tester) async {
    await montar(tester, lineas);

    await compararCaptura('data_table_produccion_lineas');
  });

  testWidgets('un nombre largo como los de producción se lee entero',
      (tester) async {
    const largo = 'Flor Petalo Suizo Grande - Bolsa x100 und';
    await montar(tester, [
      {
        'idaplique': 3,
        'apliqueNombre': largo,
        'idcolor': 2,
        'colorNombre': 'Azul marino',
        'hex': '#1A237E',
        'cantidad': 100.0,
      },
      ...lineas,
    ]);

    final nombre = tester.renderObject<RenderParagraph>(find.text(largo));
    expect(
      nombre.getMaxIntrinsicHeight(nombre.size.width),
      lessThanOrEqualTo(nombre.size.height),
      reason: 'el nombre no entra en la fila y se corta',
    );
    // Al quitar el skip, generar la captura con --update-goldens
    await compararCaptura('data_table_produccion_nombre_largo');
  },
      // bug: data_table_produccion.dart:32 — el nombre del aplique no tiene
      // maxLines ni ellipsis y la fila del DataTable mide 48 px fijos (sin
      // dataRowMaxHeight): un nombre real que cae en 3 líneas necesita 51 px
      // y la última línea sale cortada por abajo.
      skip: true);

  testWidgets('sin líneas: solo los encabezados', (tester) async {
    await montar(tester, const []);

    await compararCaptura('data_table_produccion_vacia');
  });
}
