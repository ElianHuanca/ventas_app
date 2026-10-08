import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/widgets/data_table_telas.dart';

void main() {
  const encabezados = ['Nombre', 'Cantidad', 'Precio', 'Total', ''];
  final lineas = [
    {
      'idtelas': 1,
      'nombre': 'Lino',
      'cantidad': 2.0,
      'precio': 100.0,
      'total': 200.0,
      'ganancias': 80.0,
    },
    {
      'idtelas': 2,
      'nombre': 'Seda',
      'cantidad': 1.5,
      'precio': 40.0,
      'total': 60.0,
      'ganancias': 15.0,
    },
  ];

  Future<void> montar(
    WidgetTester tester, {
    required List<Map<String, dynamic>> listbody,
    required double total,
    void Function(int, double, double)? onTap,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DataTableMapTelas(
          listheader: encabezados,
          listbody: listbody,
          total: total,
          onTap: onTap ?? (_, __, ___) {},
        ),
      ),
    ));
  }

  testWidgets('renderiza encabezados, una fila por línea y el total',
      (tester) async {
    await montar(tester, listbody: lineas, total: 260);

    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Cantidad'), findsOneWidget);
    expect(find.text('Precio'), findsOneWidget);
    // 'Total' es encabezado y también la etiqueta de la fila de total
    expect(find.text('Total'), findsNWidgets(2));

    expect(find.text('Lino'), findsOneWidget);
    expect(find.text('2.0mts'), findsOneWidget);
    expect(find.text('100.0Bs'), findsOneWidget);
    expect(find.text('200.0Bs'), findsOneWidget);
    expect(find.text('Seda'), findsOneWidget);
    expect(find.text('1.5mts'), findsOneWidget);
    expect(find.text('40.0Bs'), findsOneWidget);
    expect(find.text('60.0Bs'), findsOneWidget);

    expect(find.text('260.0 Bs'), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever_rounded), findsNWidgets(2));
  });

  testWidgets(
      'quitar llama onTap con idtelas, cantidad y precio sin pedir confirmación',
      (tester) async {
    final llamadas = <List<Object>>[];
    await montar(
      tester,
      listbody: lineas,
      total: 260,
      onTap: (idtelas, cantidad, precio) =>
          llamadas.add([idtelas, cantidad, precio]),
    );

    await tester.tap(find.byIcon(Icons.delete_forever_rounded).last);
    await tester.pumpAndSettle();

    expect(llamadas.single, [2, 1.5, 40.0]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('sin líneas muestra solo la fila de total en 0', (tester) async {
    await montar(tester, listbody: const [], total: 0);

    expect(find.byIcon(Icons.delete_forever_rounded), findsNothing);
    expect(find.textContaining('mts'), findsNothing);
    expect(find.text('0.0 Bs'), findsOneWidget);
  });
}
