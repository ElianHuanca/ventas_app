import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';

void main() {
  group('ItemDashboard', () {
    Future<void> montar(WidgetTester tester, {required VoidCallback onTap}) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SizedBox.square(
              dimension: 200,
              child: ItemDashboard(
                title: 'Sucursal Centro',
                iconData: Icons.store,
                onTap: onTap,
              ),
            ),
          ),
        ));

    testWidgets('muestra el título en mayúsculas y el ícono', (tester) async {
      await montar(tester, onTap: () {});

      expect(find.text('SUCURSAL CENTRO'), findsOneWidget);
      expect(find.text('Sucursal Centro'), findsNothing);
      expect(find.byIcon(Icons.store), findsOneWidget);
    });

    testWidgets('tocar la tarjeta ejecuta onTap', (tester) async {
      var taps = 0;
      await montar(tester, onTap: () => taps++);

      await tester.tap(find.byType(ItemDashboard));
      await tester.pump();
      expect(taps, 1);

      // También desde el ícono (toda la tarjeta es tocable)
      await tester.tap(find.byIcon(Icons.store));
      await tester.pump();
      expect(taps, 2);
    });
  });
}
