import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';

import '../datos.dart';
import '../helpers.dart';

void ventaApliquesTests() {
  group('venta de apliques', () {
    late Datos datos;
    late Sucursal sucursal;
    late Aplique aplique;
    late ColorItem color;

    /// Sucursal con un aplique (costo 5) y un color vinculado, con stock.
    Future<void> preparar({required num stock}) async {
      datos = Datos();
      sucursal = await datos.sucursal('Venta apliques');
      aplique = await datos.aplique('Mariposa', costo: 5);
      color = await datos.color('Fucsia', hex: 'E91E63');
      await datos.vincularColor(aplique, color);
      await datos.fabricar(sucursal, aplique, color, stock);
    }

    Future<void> abrirRegistro(WidgetTester tester) async {
      await irDesdeMenu(tester, 'Venta apliques');
      await tocar(tester, tarjeta(sucursal.nombre));
      await esperarHasta(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.byType(DropdownMenu<Aplique>));
    }

    Future<void> agregarLinea(
        WidgetTester tester, String cantidad, String precio) async {
      await elegir(tester, find.byType(DropdownMenu<Aplique>), aplique.nombre);
      await elegir(
          tester, find.byType(DropdownMenu<StockAplique>), color.nombre);
      await escribir(tester, campo('Cantidad'), cantidad);
      await escribir(tester, campo('Precio'), precio);
      await tocar(tester, find.text('Añadir'));
    }

    Future<void> guardarConfirmando(WidgetTester tester) async {
      await tocar(tester, find.text('Guardar'));
      await esperarHasta(tester, find.text('Confirmar Venta'));
      await tester.tap(find.text('Confirmar'));
      await esperarHasta(tester, find.text(snackOk));
    }

    testWidgets('registra la venta del día y descuenta el stock',
        (tester) async {
      await preparar(stock: 10);
      await iniciarSesionDirecto();
      await montarApp(tester);

      await abrirRegistro(tester);
      await agregarLinea(tester, '3', '12');
      expect(find.text('36.0 Bs'), findsWidgets); // total del carrito
      await guardarConfirmando(tester);
      await esperarHasta(tester, tarjeta(changeFormatDate(DateTime.now())));

      expect(await stockDe(sucursal, aplique, color), 7);
      final ventas = await db
          .from('ventas_apliques')
          .select('id, total, ganancias, descuento')
          .eq('idsucursales', sucursal.id);
      expect(ventas, hasLength(1));
      expect(numero(ventas.single['total']), 36);
      expect(numero(ventas.single['ganancias']), 21); // (12-5)*3
      final lineas = await db
          .from('detalle_ventas_apliques')
          .select('idapliques, idcolor, cantidad, precio')
          .eq('idventa', ventas.single['id']);
      expect(lineas, hasLength(1));
      expect(lineas.single['idapliques'], aplique.id);
      expect(lineas.single['idcolor'], color.id);
      expect(numero(lineas.single['cantidad']), 3);
    });

    testWidgets('no deja vender más que el stock', (tester) async {
      await preparar(stock: 2);
      await iniciarSesionDirecto();
      await montarApp(tester);

      await abrirRegistro(tester);
      await agregarLinea(tester, '5', '12');
      await esperarHasta(tester, find.textContaining('Stock insuficiente'));

      // Sin líneas en el carrito no se puede guardar
      await tocar(tester, find.text('Guardar'));
      await esperarHasta(
          tester, find.text('Agregue al menos un aplique a la venta'));
      final ventas = await db
          .from('ventas_apliques')
          .select('id')
          .eq('idsucursales', sucursal.id);
      expect(ventas, isEmpty);
      expect(await stockDe(sucursal, aplique, color), 2);
    });

    testWidgets(
        'una línea quitada del carrito no se vende ni descuenta su stock, y '
        'el descuento queda en la venta', (tester) async {
      await preparar(stock: 10);
      final verde = await datos.color('Verde', hex: '27AE60');
      await datos.vincularColor(aplique, verde);
      await datos.fabricar(sucursal, aplique, verde, 10);
      await iniciarSesionDirecto();
      await montarApp(tester);

      await abrirRegistro(tester);
      await agregarLinea(tester, '2', '12');
      await elegir(tester, find.byType(DropdownMenu<Aplique>), aplique.nombre);
      await elegir(
          tester, find.byType(DropdownMenu<StockAplique>), verde.nombre);
      await escribir(tester, campo('Cantidad'), '4');
      await escribir(tester, campo('Precio'), '12');
      await tocar(tester, find.text('Añadir'));
      expect(find.text('72.0 Bs'), findsWidgets);

      // La última línea añadida (la verde) queda arriba
      await tocar(tester, find.byIcon(Icons.delete_forever_rounded).first);
      expect(find.text('24.0 Bs'), findsWidgets);
      await escribir(tester, campo('Descuento'), '4');
      expect(find.text('20.0 Bs'), findsOneWidget); // total a pagar
      await guardarConfirmando(tester);

      expect(await stockDe(sucursal, aplique, color), 8);
      expect(await stockDe(sucursal, aplique, verde), 10);
      final venta = await db
          .from('ventas_apliques')
          .select('id, descuento')
          .eq('idsucursales', sucursal.id)
          .single();
      expect(numero(venta['descuento']), 4);
      final lineas = await db
          .from('detalle_ventas_apliques')
          .select('idcolor, cantidad')
          .eq('idventa', venta['id']);
      expect(lineas, hasLength(1));
      expect(lineas.single['idcolor'], color.id);
      expect(numero(lineas.single['cantidad']), 2);
    });

    testWidgets(
        'una segunda venta el mismo día se suma a la venta del día y el '
        'detalle la muestra', (tester) async {
      await preparar(stock: 10);
      await datos.venderApliques(sucursal, aplique, color, 3, 12);
      await iniciarSesionDirecto();
      await montarApp(tester);

      await abrirRegistro(tester);
      await agregarLinea(tester, '2', '12');
      await guardarConfirmando(tester);

      final ventas = await db
          .from('ventas_apliques')
          .select('id, total')
          .eq('idsucursales', sucursal.id);
      expect(ventas, hasLength(1), reason: 'una venta por sucursal y día');
      expect(numero(ventas.single['total']), 60);
      final lineas = await db
          .from('detalle_ventas_apliques')
          .select('cantidad')
          .eq('idventa', ventas.single['id']);
      expect(lineas, hasLength(1), reason: 'mismo aplique, color y precio');
      expect(numero(lineas.single['cantidad']), 5);
      expect(await stockDe(sucursal, aplique, color), 5);

      // Listado → detalle del día
      final hoy = tarjeta(changeFormatDate(DateTime.now()));
      await esperarHasta(tester, hoy);
      await tester.tap(hoy);
      await esperarHasta(tester, find.text('5.0 uds x 12.0 Bs'));
      expect(find.text('60.0 Bs'), findsWidgets); // línea y total
    });
  });
}
