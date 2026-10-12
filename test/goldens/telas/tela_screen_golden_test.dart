@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

void main() {
  final lino = Tela(
    id: 3,
    nombre: 'Lino',
    precxmen: 35,
    precxmay: 30,
    precxrollo: 1500,
    precxcompra: 22,
  );
  final seda = Tela(
    id: 4,
    nombre: 'Seda',
    precxmen: 60,
    precxmay: 52,
    precxrollo: 2800,
    precxcompra: 40,
    activo: false,
  );

  /// Monta el formulario de la tela [id] (0 = alta) con sus dos blocs,
  /// como en app_router.
  Future<void> montar(WidgetTester tester, int id) async {
    final repo = FakeTelasRepository(telas: [lino, seda]);
    final telasBloc = TelasBloc(telasRepository: repo);
    final telaBloc = TelaBloc(telasRepository: repo, id: id);
    addTearDown(telasBloc.close);
    addTearDown(telaBloc.close);
    await montarParaCaptura(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: telasBloc),
          BlocProvider.value(value: telaBloc),
        ],
        child: TelaScreen(id: id),
      ),
    );
  }

  Finder campo(String label) => find.widgetWithText(TextFormField, label);

  testWidgets('alta vacía', (tester) async {
    await montar(tester, 0);

    await compararCaptura('tela_alta');
  });

  testWidgets('edición con los datos precargados', (tester) async {
    await montar(tester, 3);

    await compararCaptura('tela_edicion');
  });

  testWidgets('edición de una tela inactiva (switch apagado)', (tester) async {
    await montar(tester, 4);

    await compararCaptura('tela_edicion_inactiva');
  });

  testWidgets('error de validación: falta un precio', (tester) async {
    await montar(tester, 0);
    await tester.enterText(campo('Nombre'), 'Gabardina');
    await tester.enterText(campo('Precio X Menor'), '28');
    await tester.enterText(campo('Precio X Mayor'), '24.5');
    await tester.enterText(campo('Precio Compra'), '18');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // El formulario no marca el campo: solo avisa con el snackbar
    expect(find.text('Hubo un error'), findsOneWidget);
    await compararCaptura('tela_error_validacion');
  });
}
