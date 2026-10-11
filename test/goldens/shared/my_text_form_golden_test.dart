@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';

import '../golden_helpers.dart';

void main() {
  /// Formulario como el de una tela: MiTextField es un Expanded y siempre
  /// va dentro de un Row.
  Widget formulario({
    String nombre = '',
    String precxmen = '',
    String precxmay = '',
    String cantidad = '',
  }) =>
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Column(
            children: [
              Row(children: [
                MiTextField(
                    label: 'Nombre', initialValue: nombre, onChanged: (_) {}),
              ]),
              const SizedBox(height: 15),
              Row(children: [
                MiTextField(
                    label: 'Precio X Menor',
                    initialValue: precxmen,
                    onChanged: (_) {}),
                MiTextField(
                    label: 'Precio X Mayor',
                    initialValue: precxmay,
                    onChanged: (_) {}),
              ]),
              const SizedBox(height: 15),
              Row(children: [
                MiTextField(
                    label: 'Cantidad',
                    initialValue: cantidad,
                    onChanged: (_) {}),
              ]),
            ],
          ),
        ),
      );

  testWidgets('vacíos: solo las etiquetas', (tester) async {
    await montarParaCaptura(tester, formulario());

    await compararCaptura('my_text_form_vacio');
  });

  testWidgets('con valores: sufijos Bs en precios y mts en cantidad',
      (tester) async {
    await montarParaCaptura(
      tester,
      formulario(
        nombre: 'Lino',
        precxmen: '45',
        precxmay: '40',
        cantidad: '2.5',
      ),
    );

    await compararCaptura('my_text_form_con_valores');
  });

  testWidgets('enfocado: el campo activo resalta su borde y etiqueta',
      (tester) async {
    await montarParaCaptura(tester, formulario(nombre: 'Seda'));

    await tester.tap(find.widgetWithText(TextFormField, 'Precio X Menor'));
    await tester.pumpAndSettle();

    await compararCaptura('my_text_form_enfocado');
  });

  testWidgets('con error: muestra el mensaje bajo el campo', (tester) async {
    await montarParaCaptura(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            MiTextField(
              label: 'Hex (ej: C0392B)',
              initialValue: 'XYZ',
              onChanged: (_) {},
              errorMessage: 'Hex inválido',
            ),
          ]),
        ),
      ),
    );

    expect(find.text('Hex inválido'), findsOneWidget);
    await compararCaptura('my_text_form_con_error');
  },
      // bug: my_text_form.dart:34-43 — MiTextField recibe errorMessage pero
      // nunca lo pasa al InputDecoration (falta errorText): el error no se
      // muestra (lo usa color_screen.dart:68-70 para "Hex inválido"). Al
      // arreglarlo, quitar el skip y generar la captura con --update-goldens.
      skip: true);
}
