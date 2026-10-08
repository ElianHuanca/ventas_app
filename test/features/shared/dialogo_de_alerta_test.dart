import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';

void main() {
  group('dialogoDeAlerta', () {
    late int confirmaciones;

    setUp(() => confirmaciones = 0);

    /// Pantalla con un botón que abre el diálogo; [personalizado] usa textos
    /// propios en vez de los de eliminar.
    Future<void> abrir(WidgetTester tester, {bool personalizado = false}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => personalizado
                  ? dialogoDeAlerta(
                      context,
                      () => confirmaciones++,
                      titulo: 'Cerrar venta',
                      mensaje: '¿Registrar la venta del día?',
                      textoConfirmar: 'Registrar',
                    )
                  : dialogoDeAlerta(context, () => confirmaciones++),
              child: const Text('abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('por defecto pide confirmar la eliminación', (tester) async {
      await abrir(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Confirmar Eliminación'), findsOneWidget);
      expect(find.text('¿Está seguro de que desea eliminar este elemento?'),
          findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('Cancelar cierra el diálogo sin ejecutar la acción',
        (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(confirmaciones, 0);
    });

    testWidgets('confirmar cierra el diálogo y ejecuta la acción una vez',
        (tester) async {
      await abrir(tester);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(confirmaciones, 1);
    });

    testWidgets('acepta título, mensaje y texto de confirmación propios',
        (tester) async {
      await abrir(tester, personalizado: true);

      expect(find.text('Cerrar venta'), findsOneWidget);
      expect(find.text('¿Registrar la venta del día?'), findsOneWidget);
      expect(find.text('Eliminar'), findsNothing);

      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();

      expect(confirmaciones, 1);
    });
  });
}
