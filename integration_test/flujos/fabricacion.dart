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

    testWidgets(
        'con fecha anterior registra la producción de ese día, sin las líneas '
        'quitadas', (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Fabricacion fecha');
      final aplique = await datos.aplique('Sol');
      final rojo = await datos.color('Rojo', hex: 'C0392B');
      final azul = await datos.color('Azul', hex: '2980B9');
      await datos.vincularColor(aplique, rojo);
      await datos.vincularColor(aplique, azul);
      final antes = DateTime.now().subtract(const Duration(days: 1));
      final ayer = DateTime(antes.year, antes.month, antes.day);
      await iniciarSesionDirecto();
      await montarApp(tester);

      await irDesdeMenu(tester, 'Fabricación');
      await tocar(tester, tarjeta(sucursal.nombre));
      await esperarHasta(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.byType(DropdownMenu<Aplique>));
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await elegirFecha(tester, ayer);

      await elegir(tester, find.byType(DropdownMenu<Aplique>), aplique.nombre);
      await elegir(tester, find.byType(DropdownMenu<ColorItem>), rojo.nombre);
      await escribir(tester, campo('Cantidad fabricada'), '3');
      await tocar(tester, find.text('Añadir'));
      await elegir(tester, find.byType(DropdownMenu<ColorItem>), azul.nombre);
      await escribir(tester, campo('Cantidad fabricada'), '5');
      await tocar(tester, find.text('Añadir'));
      // La última línea añadida (la azul) queda arriba
      await tocar(tester, find.byIcon(Icons.delete_forever_rounded).first);
      expect(find.text('5.0 uds'), findsNothing);
      expect(find.text('3.0 uds'), findsOneWidget);
      await tocar(tester, find.text('Guardar'));

      await esperarQue(() async => await stockDe(sucursal, aplique, rojo) == 3,
          descripcion: 'stock 3 del rojo');
      expect(await stockDe(sucursal, aplique, azul), 0);
      final producciones = await db
          .from('producciones')
          .select('id, fecha')
          .eq('sucursal_id', sucursal.id);
      expect(producciones, hasLength(1));
      expect(producciones.single['fecha'],
          ayer.toIso8601String().substring(0, 10));
      final lineas = await db
          .from('detalle_produccion')
          .select('idcolor, cantidad')
          .eq('idproduccion', producciones.single['id']);
      expect(lineas, hasLength(1));
      expect(lineas.single['idcolor'], rojo.id);

      // El historial la muestra en su fecha, no en la de hoy
      await volver(tester);
      await esperarHasta(tester, tarjeta(changeFormatDate(ayer)));
      expect(tarjeta(changeFormatDate(DateTime.now())), findsNothing);
    });
  });
}
