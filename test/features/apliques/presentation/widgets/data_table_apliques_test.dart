import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/presentation/widgets/data_table_apliques.dart';

void main() {
  final lineas = [
    {
      'idapliques': 1,
      'idcolor': 5,
      'nombre': 'Flor (Rojo)',
      'cantidad': 2.0,
      'precio': 25.0,
      'total': 50.0,
      'ganancias': 30.0,
    },
    {
      'idapliques': 2,
      'idcolor': 7,
      'nombre': 'Luna (Azul)',
      'cantidad': 1.5,
      'precio': 10.0,
      'total': 15.0,
      'ganancias': 6.0,
    },
  ];

  Future<void> montar(
    WidgetTester tester, {
    required List<Map<String, dynamic>> listbody,
    required double total,
    void Function(int, int, double, double)? onTap,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DataTableApliques(
          listbody: listbody,
          total: total,
          onTap: onTap ?? (_, __, ___, ____) {},
        ),
      ),
    ));
  }

  testWidgets('renderiza encabezados y una fila por línea con sus importes',
      (tester) async {
    await montar(tester, listbody: lineas, total: 65);

    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Cantidad'), findsOneWidget);
    expect(find.text('Precio'), findsOneWidget);
    // 'Total' aparece como encabezado y como etiqueta de la fila de total
    expect(find.text('Total'), findsNWidgets(2));

    expect(find.text('Flor (Rojo)'), findsOneWidget);
    expect(find.text('2.0'), findsOneWidget);
    expect(find.text('25.0Bs'), findsOneWidget);
    expect(find.text('50.0Bs'), findsOneWidget);

    expect(find.text('Luna (Azul)'), findsOneWidget);
    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('10.0Bs'), findsOneWidget);
    expect(find.text('15.0Bs'), findsOneWidget);

    // Un botón de quitar por línea (la fila de total no tiene)
    expect(find.byIcon(Icons.delete_forever_rounded), findsNWidgets(2));
  });

  testWidgets('muestra el total recibido en la última fila', (tester) async {
    await montar(tester, listbody: lineas, total: 65);

    expect(find.text('65.0 Bs'), findsOneWidget);
  });

  testWidgets(
      'el botón quitar llama onTap con idapliques, idcolor, cantidad y precio '
      'de su fila', (tester) async {
    final llamadas = <List<Object>>[];
    await montar(
      tester,
      listbody: lineas,
      total: 65,
      onTap: (idapliques, idcolor, cantidad, precio) =>
          llamadas.add([idapliques, idcolor, cantidad, precio]),
    );

    await tester.tap(find.byIcon(Icons.delete_forever_rounded).last);
    await tester.tap(find.byIcon(Icons.delete_forever_rounded).first);

    expect(llamadas, [
      [2, 7, 1.5, 10.0],
      [1, 5, 2.0, 25.0],
    ]);
  });

  testWidgets('cantidad y precio enteros llegan al callback como double',
      (tester) async {
    final llamadas = <List<Object>>[];
    await montar(
      tester,
      listbody: [
        {
          'idapliques': 3,
          'idcolor': 9,
          'nombre': 'Estrella (Verde)',
          'cantidad': 4,
          'precio': 12,
          'total': 48,
        },
      ],
      total: 48,
      onTap: (idapliques, idcolor, cantidad, precio) =>
          llamadas.add([idapliques, idcolor, cantidad, precio]),
    );

    await tester.tap(find.byIcon(Icons.delete_forever_rounded));

    expect(llamadas.single, [3, 9, 4.0, 12.0]);
    expect(llamadas.single[2], isA<double>());
    expect(llamadas.single[3], isA<double>());
  });

  testWidgets('sin líneas solo muestra la fila de total en 0', (tester) async {
    await montar(tester, listbody: const [], total: 0);

    expect(find.byIcon(Icons.delete_forever_rounded), findsNothing);
    expect(find.text('0.0 Bs'), findsOneWidget);
    expect(find.textContaining('Bs'), findsOneWidget);
  });
}
