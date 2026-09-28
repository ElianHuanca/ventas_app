import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/presentation/widgets/data_table_produccion.dart';

void main() {
  final lineas = [
    {
      'idaplique': 1,
      'apliqueNombre': 'Flor',
      'idcolor': 1,
      'colorNombre': 'Rojo',
      'hex': '#FF0000',
      'cantidad': 3.0,
    },
    {
      'idaplique': 2,
      'apliqueNombre': 'Luna',
      'idcolor': 3,
      'colorNombre': 'Azul',
      'hex': '#0000FF',
      'cantidad': 1.5,
    },
  ];

  testWidgets('renderiza las líneas con aplique, color y cantidad',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DataTableProduccion(listbody: lineas, onTap: (_, __, ___) {}),
      ),
    ));

    expect(find.text('Aplique'), findsOneWidget);
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Cantidad'), findsOneWidget);
    expect(find.text('Flor'), findsOneWidget);
    expect(find.text('Rojo'), findsOneWidget);
    expect(find.text('3.0 uds'), findsOneWidget);
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Azul'), findsOneWidget);
    expect(find.text('1.5 uds'), findsOneWidget);
  });

  testWidgets('el botón quitar llama onTap con idaplique, idcolor y cantidad',
      (tester) async {
    final llamadas = <List<Object>>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DataTableProduccion(
          listbody: lineas,
          onTap: (idaplique, idcolor, cantidad) =>
              llamadas.add([idaplique, idcolor, cantidad]),
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.delete_forever_rounded).first);

    expect(llamadas.single, [1, 1, 3.0]);
  });

  testWidgets('sin líneas no renderiza filas', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DataTableProduccion(listbody: const [], onTap: (_, __, ___) {}),
      ),
    ));

    expect(find.byIcon(Icons.delete_forever_rounded), findsNothing);
    expect(find.textContaining('uds'), findsNothing);
  });
}
