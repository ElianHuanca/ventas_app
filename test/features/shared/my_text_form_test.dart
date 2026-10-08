import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';

void main() {
  group('MiTextField', () {
    /// MiTextField es un Expanded: siempre va dentro de un Row.
    Future<void> montar(WidgetTester tester, List<Widget> campos) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Row(children: campos)),
        ));

    InputDecoration decoracion(WidgetTester tester, {int index = 0}) =>
        tester.widget<TextField>(find.byType(TextField).at(index)).decoration!;

    testWidgets('muestra la etiqueta y el valor inicial', (tester) async {
      await montar(tester, [
        MiTextField(label: 'Nombre', initialValue: 'Lino', onChanged: (_) {}),
      ]);

      expect(find.text('Nombre'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Lino'), findsOneWidget);
    });

    testWidgets('escribir llama onChanged con el texto', (tester) async {
      final recibidos = <String>[];
      await montar(tester, [
        MiTextField(label: 'Nombre', onChanged: recibidos.add),
      ]);

      await tester.enterText(find.byType(TextFormField), 'Seda');

      expect(recibidos, ['Seda']);
    });

    testWidgets('con controller muestra su texto', (tester) async {
      final controller = TextEditingController(text: 'Algodón');
      addTearDown(controller.dispose);
      await montar(tester, [
        MiTextField(label: 'Nombre', controller: controller, onChanged: null),
      ]);

      expect(find.widgetWithText(TextFormField, 'Algodón'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Lino');
      expect(controller.text, 'Lino');
    });

    testWidgets('sufijo " mts" para Cantidad, " Bs" para precios y nada en '
        'el resto', (tester) async {
      await montar(tester, [
        MiTextField(label: 'Cantidad', onChanged: (_) {}),
        MiTextField(label: 'Precio x Menor', onChanged: (_) {}),
        MiTextField(label: 'Nombre', onChanged: (_) {}),
      ]);

      expect(decoracion(tester, index: 0).suffixText, ' mts');
      expect(decoracion(tester, index: 1).suffixText, ' Bs');
      expect(decoracion(tester, index: 2).suffixText, '');
    });

    testWidgets('teclado de texto por defecto o el indicado', (tester) async {
      await montar(tester, [
        MiTextField(label: 'Nombre', onChanged: (_) {}),
        MiTextField(
          label: 'Cantidad',
          onChanged: (_) {},
          keyboardType: TextInputType.number,
        ),
      ]);

      final campos =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(campos[0].keyboardType, TextInputType.text);
      expect(campos[1].keyboardType, TextInputType.number);
    });

    testWidgets('flex 1 por defecto o el indicado', (tester) async {
      await montar(tester, [
        MiTextField(label: 'Nombre', onChanged: (_) {}),
        MiTextField(label: 'Cantidad', onChanged: (_) {}, flex: 3),
      ]);

      final expandidos =
          tester.widgetList<Expanded>(find.byType(Expanded)).toList();
      expect(expandidos.map((e) => e.flex), [1, 3]);
      // El ancho se reparte según el flex
      final anchos = tester
          .widgetList(find.byType(MiTextField))
          .map((w) => tester.getSize(find.byWidget(w)).width)
          .toList();
      expect(anchos[1], closeTo(anchos[0] * 3, 0.01));
    });
  });
}
