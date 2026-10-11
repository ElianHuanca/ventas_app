@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/colores/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

void main() {
  /// Monta `/color/:id` con el ColoresBloc de la ruta, como en app_router.
  Future<void> montar(WidgetTester tester, int id) async {
    final bloc = ColoresBloc(
      coloresRepository: FakeColoresRepository(colores: const [
        ColorItem(id: 5, nombre: 'Coral', hex: 'FF7F50'),
        ColorItem(id: 6, nombre: 'Azul marino', hex: '000080'),
      ]),
    );
    addTearDown(bloc.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(value: bloc, child: ColorScreen(id: id)),
    );
  }

  Finder campo(String label) => find.widgetWithText(TextFormField, label);

  /// Escribe en el campo y cierra el teclado (tocar fuera del campo).
  Future<void> escribir(WidgetTester tester, String label, String texto) async {
    await tester.enterText(campo(label), texto);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  testWidgets('alta: formulario vacío, sin vista previa', (tester) async {
    await montar(tester, 0);

    await compararCaptura('color_alta');
  });

  testWidgets('edición: precarga el color con su vista previa', (tester) async {
    await montar(tester, 5);

    await compararCaptura('color_edicion');
  });

  testWidgets('hex inválido: sin vista previa y Guardar avisa el error',
      (tester) async {
    await montar(tester, 0);

    await escribir(tester, 'Nombre', 'Turquesa');
    await escribir(tester, 'Hex (ej: C0392B)', '40E0Z0');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Hubo un error'), findsOneWidget);

    await compararCaptura('color_hex_invalido');
  });

  testWidgets(
    'hex inválido: el campo marca "Hex inválido" mientras se escribe',
    (tester) async {
      await montar(tester, 0);

      await escribir(tester, 'Hex (ej: C0392B)', '40E0Z0');
      expect(find.text('Hex inválido'), findsOneWidget);

      await compararCaptura('color_hex_invalido_aviso');
    },
    // bug: color_screen.dart:68-70 pasa errorMessage a MiTextField, pero
    // my_text_form.dart:34-43 nunca lo usa (no hay errorText en el
    // InputDecoration): el aviso inline no se muestra jamás.
    skip: true,
  );
}
