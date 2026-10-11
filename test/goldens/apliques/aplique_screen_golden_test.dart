@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

void main() {
  final apliques = [
    Aplique(
      id: 7,
      nombre: 'Flor bordada 10x10 - Bolsa x100 und',
      costoFabricacion: 12.5,
      anchoCm: 10,
      altoCm: 10,
    ),
    Aplique(
      id: 8,
      nombre: 'Mariposa lentejuela 8x6',
      costoFabricacion: 9.5,
      anchoCm: 8,
      altoCm: 6,
      activo: false,
    ),
  ];

  Future<void> montar(WidgetTester tester, int id) async {
    final bloc = ApliquesBloc(
      apliquesRepository: FakeApliquesRepository(apliques: apliques),
    );
    addTearDown(bloc.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(value: bloc, child: ApliqueScreen(id: id)),
    );
  }

  Finder campo(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('alta: formulario vacío', (tester) async {
    await montar(tester, 0);

    await compararCaptura('aplique_screen_alta');
  });

  testWidgets('edición: datos precargados y switch Activo encendido',
      (tester) async {
    await montar(tester, 7);

    await compararCaptura('aplique_screen_edicion');
  });

  testWidgets('edición de un aplique inactivo: switch apagado', (tester) async {
    await montar(tester, 8);

    await compararCaptura('aplique_screen_edicion_inactivo');
  });

  testWidgets('error de validación: sin nombre avisa "Hubo un error"',
      (tester) async {
    await montar(tester, 0);
    await tester.enterText(campo('Ancho (cm)'), '5');
    await tester.enterText(campo('Alto (cm)'), '5');
    await tester.enterText(campo('Costo de fabricación'), '4');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    await compararCaptura('aplique_screen_error_validacion');
  });
}
