@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';

import '../golden_helpers.dart';

void main() {
  testWidgets('variantes: normal, "Eliminar" y con color propio',
      (tester) async {
    await montarParaCaptura(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Fila de botones de un formulario de edición
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MaterialButtonWidget(onTap: () {}, texto: 'Modificar'),
                  const SizedBox(width: 15),
                  MaterialButtonWidget(onTap: () {}, texto: 'Eliminar'),
                ],
              ),
              const SizedBox(height: 20),
              MaterialButtonWidget(onTap: () {}, texto: 'Guardar'),
              const SizedBox(height: 20),
              MaterialButtonWidget(
                onTap: () {},
                texto: 'Añadir',
                buttonColor: Colors.indigo,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(MaterialButton), findsNWidgets(4));
    await compararCaptura('material_button_widget_variantes');
  });
}
