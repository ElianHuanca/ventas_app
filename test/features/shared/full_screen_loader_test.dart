import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';

void main() {
  group('FullScreenLoader', () {
    testWidgets('muestra un indicador de carga centrado', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FullScreenLoader()));

      expect(
        find.descendant(
          of: find.byType(Center),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      final indicador = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator));
      expect(indicador.strokeWidth, 2);
    });

    testWidgets('ocupa todo el espacio disponible', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FullScreenLoader()));

      final pantalla = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getSize(find.byType(FullScreenLoader)), pantalla);
      expect(tester.getCenter(find.byType(CircularProgressIndicator)),
          pantalla.center(Offset.zero));
    });
  });
}
