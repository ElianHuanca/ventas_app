import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../datos.dart';
import '../helpers.dart';

void dashboardTests() {
  group('dashboard', () {
    // Las ventas son de hoy: caen en el rango por defecto (este mes)

    testWidgets('la pestaña Telas muestra las telas vendidas, en metros',
        (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Dashboard telas');
      final tela = await datos.tela('Gasa');
      await datos.venderTela(sucursal, tela, 2.5, 20);
      await iniciarSesionDirecto();
      await montarApp(tester);

      await irDesdeMenu(tester, 'Dashboard');
      await esperarHasta(tester, find.text('Por cantidad'));
      await tester.scrollUntilVisible(find.text(tela.nombre), 200,
          scrollable: listaVertical.first);

      await tester.scrollUntilVisible(find.text('Por cantidad'), -200,
          scrollable: listaVertical.first);
      await tester.tap(find.text('Por cantidad'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(tela.nombre), 200,
          scrollable: listaVertical.first);
      final fila = find
          .ancestor(of: find.text(tela.nombre), matching: find.byType(Row))
          .first;
      expect(find.descendant(of: fila, matching: find.text('2.50 mts')),
          findsOneWidget);
    });

    testWidgets('la pestaña Apliques muestra los apliques vendidos',
        (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Dashboard apliques');
      final aplique = await datos.aplique('Flor');
      final color = await datos.color('Lila', hex: '9B59B6');
      await datos.vincularColor(aplique, color);
      await datos.fabricar(sucursal, aplique, color, 10);
      await datos.venderApliques(sucursal, aplique, color, 3, 12);
      await iniciarSesionDirecto();
      await montarApp(tester);

      await irDesdeMenu(tester, 'Dashboard');
      await esperarHasta(tester, find.text('Apliques'));
      await tester.tap(find.text('Apliques'));
      await tester.pumpAndSettle();
      await esperarHasta(tester, listaVertical);
      // El ranking usa el nombre de la tabla apliques, no el del detalle
      await tester.scrollUntilVisible(find.text(aplique.nombre), 200,
          scrollable: listaVertical.first);

      await tester.scrollUntilVisible(find.text('Por cantidad'), -200,
          scrollable: listaVertical.first);
      await tester.tap(find.text('Por cantidad'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(aplique.nombre), 200,
          scrollable: listaVertical.first);
      final fila = find
          .ancestor(of: find.text(aplique.nombre), matching: find.byType(Row))
          .first;
      expect(find.descendant(of: fila, matching: find.text('3 uds')),
          findsOneWidget);
    });
  });
}
