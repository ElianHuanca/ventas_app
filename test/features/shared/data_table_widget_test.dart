import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/widgets/data_table_widget.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';

void main() {
  const encabezados = ['Tela', 'Cantidad', 'Precio', 'Total', 'Accion'];
  const lineas = [
    DetalleVenta(
        id: 1,
        nombre: 'Lino',
        precio: 100,
        cantidad: 2,
        total: 200,
        ganancias: 80,
        idtelas: 1),
    DetalleVenta(
        id: 2,
        nombre: 'Seda',
        precio: 45,
        cantidad: 3,
        total: 135,
        ganancias: 45,
        idtelas: 2),
  ];

  Future<void> montar(
    WidgetTester tester, {
    List<DetalleVenta> detalles = lineas,
    void Function(int)? onTap,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => dataTableWidget(
            encabezados,
            context,
            detalles,
            335,
            125,
            15,
            onTap ?? (_) {},
          ),
        ),
      ),
    ));
  }

  testWidgets('renderiza una fila por línea y los totales de la venta',
      (tester) async {
    await montar(tester);

    expect(find.text('Tela'), findsOneWidget);
    expect(find.text('Accion'), findsOneWidget);
    // 'Total' es encabezado y también la etiqueta de la fila de total
    expect(find.text('Total'), findsNWidgets(2));

    expect(find.text('Lino'), findsOneWidget);
    expect(find.text('2.0mts'), findsOneWidget);
    expect(find.text('100.0Bs'), findsOneWidget);
    expect(find.text('200.0 Bs'), findsOneWidget);
    expect(find.text('Seda'), findsOneWidget);
    expect(find.text('3.0mts'), findsOneWidget);
    expect(find.text('45.0Bs'), findsOneWidget);
    expect(find.text('135.0 Bs'), findsOneWidget);

    expect(find.text('335.0 Bs'), findsOneWidget);
    expect(find.text('Descuento'), findsOneWidget);
    expect(find.text('15.0 Bs'), findsOneWidget);
    // Las ganancias no se muestran
    expect(find.text('Ganancias'), findsNothing);
    expect(find.text('125.0 Bs'), findsNothing);
  });

  testWidgets('línea sin nombre ni total muestra vacío y 0.0 Bs',
      (tester) async {
    await montar(tester, detalles: const [
      DetalleVenta(id: 9, precio: 10, cantidad: 1, idtelas: 4),
    ]);

    expect(find.text('1.0mts'), findsOneWidget);
    expect(find.text('0.0 Bs'), findsOneWidget);
  });

  testWidgets('borrar pide confirmación y al Eliminar llama onTap con el id',
      (tester) async {
    final borrados = <int>[];
    await montar(tester, onTap: borrados.add);

    await tester.tap(find.byIcon(Icons.delete_forever_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar Eliminación'), findsOneWidget);
    expect(find.text('¿Está seguro de que desea eliminar este elemento?'),
        findsOneWidget);
    expect(borrados, isEmpty);

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(borrados, [2]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Cancelar cierra el diálogo sin llamar onTap', (tester) async {
    final borrados = <int>[];
    await montar(tester, onTap: borrados.add);

    await tester.tap(find.byIcon(Icons.delete_forever_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(borrados, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
