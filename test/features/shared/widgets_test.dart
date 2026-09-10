import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import 'package:textiles_app/features/shared/widgets/material_button_widget.dart';
import 'package:textiles_app/features/shared/widgets/producto_colores_list.dart';

void main() {
  group('MaterialButtonWidget', () {
    testWidgets('muestra el texto y ejecuta onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MaterialButtonWidget(onTap: () => taps++, texto: 'Guardar'),
        ),
      ));

      expect(find.text('Guardar'), findsOneWidget);
      await tester.tap(find.byType(MaterialButton));
      expect(taps, 1);
    });

    testWidgets('botón normal usa fondo negro y texto blanco', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MaterialButtonWidget(onTap: () {}, texto: 'Guardar'),
        ),
      ));

      final button = tester.widget<MaterialButton>(find.byType(MaterialButton));
      expect(button.color, Colors.black);
      final text = tester.widget<Text>(find.text('Guardar'));
      expect(text.style!.color, Colors.white);
    });

    testWidgets('botón "Eliminar" usa fondo claro y texto negro',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MaterialButtonWidget(onTap: () {}, texto: 'Eliminar'),
        ),
      ));

      final button = tester.widget<MaterialButton>(find.byType(MaterialButton));
      expect(button.color, Colors.grey[50]);
      final text = tester.widget<Text>(find.text('Eliminar'));
      expect(text.style!.color, Colors.black);
    });

    testWidgets('respeta buttonColor personalizado', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MaterialButtonWidget(
              onTap: () {}, texto: 'Ok', buttonColor: Colors.red),
        ),
      ));

      final button = tester.widget<MaterialButton>(find.byType(MaterialButton));
      expect(button.color, Colors.red);
    });
  });

  group('ProductoColoresList', () {
    const colores = [
      ColorItem(id: 1, nombre: 'Rojo', hex: '#FF0000', vinculado: true),
      ColorItem(id: 2, nombre: 'Verde', hex: '#00FF00', vinculado: false),
    ];

    testWidgets('muestra un switch por color con su nombre y estado',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProductoColoresList(
            isLoading: false,
            colores: colores,
            onToggle: (_, __) {},
          ),
        ),
      ));

      expect(find.text('Rojo'), findsOneWidget);
      expect(find.text('Verde'), findsOneWidget);
      final switches =
          tester.widgetList<SwitchListTile>(find.byType(SwitchListTile));
      expect(switches.map((e) => e.value), [true, false]);
    });

    testWidgets('al tocar un switch llama onToggle con id y nuevo valor',
        (tester) async {
      int? idRecibido;
      bool? valorRecibido;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProductoColoresList(
            isLoading: false,
            colores: colores,
            onToggle: (id, valor) {
              idRecibido = id;
              valorRecibido = valor;
            },
          ),
        ),
      ));

      await tester.tap(find.text('Verde'));

      expect(idRecibido, 2);
      expect(valorRecibido, true);
    });

    testWidgets('isLoading muestra un indicador en vez de la lista',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProductoColoresList(
            isLoading: true,
            colores: colores,
            onToggle: (_, __) {},
          ),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
    });
  });
}
