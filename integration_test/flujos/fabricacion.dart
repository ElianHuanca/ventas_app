import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/shared/shared.dart';

import '../datos.dart';
import '../helpers.dart';

void fabricacionTests() {
  group('fabricación', () {
    testWidgets(
        'registrar desde la UI sube el stock y se acumula en la producción '
        'del día', (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Fabricacion');
      final aplique = await datos.aplique('Luna');
      final color = await datos.color('Dorado', hex: 'F1C40F');
      await datos.vincularColor(aplique, color);
      await iniciarSesionDirecto();
      await montarApp(tester);

      await irDesdeMenu(tester, 'Fabricación');
      await tocar(tester, tarjeta(sucursal.nombre));
      await esperarHasta(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.byType(DropdownMenu<Aplique>));
      await elegir(tester, find.byType(DropdownMenu<Aplique>), aplique.nombre);
      await elegir(tester, find.byType(DropdownMenu<ColorItem>), color.nombre);

      // Primera tanda
      await escribir(tester, campo('Cantidad fabricada'), '4');
      await tocar(tester, find.text('Añadir'));
      expect(find.text(color.nombre), findsWidgets); // línea en la tabla
      await tocar(tester, find.text('Guardar'));
      await esperarQue(() async => await stockDe(sucursal, aplique, color) == 4,
          descripcion: 'stock 4 tras la primera tanda');
      await esperarHasta(
          tester, find.textContaining('Stock actual en esta sucursal: 4'));

      // Segunda tanda el mismo día: suma a la misma línea
      await escribir(tester, campo('Cantidad fabricada'), '6');
      await tocar(tester, find.text('Añadir'));
      await tocar(tester, find.text('Guardar'));
      await esperarQue(
          () async => await stockDe(sucursal, aplique, color) == 10,
          descripcion: 'stock 10 tras la segunda tanda');

      final producciones = await db
          .from('producciones')
          .select('id')
          .eq('sucursal_id', sucursal.id);
      expect(producciones, hasLength(1), reason: 'una cabecera por día');
      final lineas = await db
          .from('detalle_produccion')
          .select('cantidad')
          .eq('idproduccion', producciones.single['id']);
      expect(lineas, hasLength(1));
      expect(numero(lineas.single['cantidad']), 10);

      // Historial → detalle del día
      await volver(tester);
      final hoy = tarjeta(changeFormatDate(DateTime.now()));
      await esperarHasta(tester, hoy);
      await tester.tap(hoy);
      await esperarHasta(
          tester, find.text('${aplique.nombre} (${color.nombre})'));
      expect(find.text('10.0 uds'), findsOneWidget);
    });
  });
}
