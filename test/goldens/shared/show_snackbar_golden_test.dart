@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';

import '../golden_helpers.dart';

void main() {
  /// Muestra el aviso sobre un formulario de la app (Screen1 con back) y
  /// espera a que termine de entrar (no se cierra: su timer de 4 s no corre
  /// con pumpAndSettle).
  Future<void> mostrar(
      WidgetTester tester, void Function(BuildContext context) aviso) async {
    await montarParaCaptura(
      tester,
      Screen1(
        backRoute: true,
        title: 'Registrar producción',
        isGridview: false,
        widget: [
          // Como el botón Guardar de ProduccionScreen
          Padding(
            padding: const EdgeInsets.all(12),
            child: MaterialButtonWidget(onTap: () {}, texto: 'Guardar'),
          ),
        ],
      ),
    );
    aviso(tester.element(find.byType(ListView)));
    await tester.pumpAndSettle();
  }

  testWidgets('showSnackbar con un texto propio', (tester) async {
    await mostrar(
      tester,
      (context) =>
          showSnackbar(context, 'Producción registrada, stock actualizado'),
    );

    expect(find.byType(SnackBar), findsOneWidget);
    await compararCaptura('show_snackbar_texto');
  });

  testWidgets('showSnackbarBool éxito: "Realizado correctamente"',
      (tester) async {
    await mostrar(
      tester,
      (context) => showSnackbarBool(context, true, popOnSuccess: false),
    );

    expect(find.text('Realizado correctamente'), findsOneWidget);
    await compararCaptura('show_snackbar_exito');
  });

  testWidgets('showSnackbarBool error: "Hubo un error"', (tester) async {
    await mostrar(tester, (context) => showSnackbarBool(context, false));

    expect(find.text('Hubo un error'), findsOneWidget);
    await compararCaptura('show_snackbar_error');
  });
}
