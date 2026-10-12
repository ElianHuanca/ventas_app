@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';

import '../golden_helpers.dart';

void main() {
  /// Abre el diálogo sobre una pantalla de la app (Screen1 con una lista de
  /// telas) para que la captura muestre también la barrera oscura.
  Future<void> abrir(
      WidgetTester tester, void Function(BuildContext context) mostrar) async {
    await montarParaCaptura(
      tester,
      const Screen1(
        backRoute: true,
        title: 'Telas',
        isGridview: false,
        widget: [
          ListTile(title: Text('Lino'), subtitle: Text('45 Bs x metro')),
          ListTile(title: Text('Seda'), subtitle: Text('60 Bs x metro')),
          ListTile(title: Text('Gabardina'), subtitle: Text('35 Bs x metro')),
        ],
      ),
    );
    mostrar(tester.element(find.byType(ListView)));
    await tester.pumpAndSettle();
  }

  testWidgets('por defecto pide confirmar la eliminación', (tester) async {
    await abrir(tester, (context) => dialogoDeAlerta(context, () {}));

    expect(find.text('Confirmar Eliminación'), findsOneWidget);
    await compararCaptura('dialogo_de_alerta_eliminar');
  });

  testWidgets('con los textos de "Confirmar Venta" de la venta de apliques',
      (tester) async {
    await abrir(
      tester,
      (context) => dialogoDeAlerta(
        context,
        () {},
        titulo: 'Confirmar Venta',
        mensaje: '¿Está seguro de registrar esta venta de apliques?',
        textoConfirmar: 'Confirmar',
      ),
    );

    expect(find.text('Confirmar Venta'), findsOneWidget);
    await compararCaptura('dialogo_de_alerta_confirmar_venta');
  });
}
