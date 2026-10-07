import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';

import '../datos.dart';
import '../helpers.dart';

void ventaTelasTests() {
  group('venta de telas', () {
    Future<void> abrirVentas(WidgetTester tester, Sucursal sucursal) async {
      // Inicio = venta de telas
      await tocar(tester, tarjeta(sucursal.nombre));
      await esperarHasta(tester, find.text('Ventas'));
    }

    /// Desde el listado de ventas: registra una venta con [lineas]
    /// (tela, cantidad, precio) y vuelve al listado.
    Future<void> venderDesdeUI(
        WidgetTester tester, List<(Tela, String, String)> lineas) async {
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.byType(DropdownMenu<Tela>));
      for (final (tela, cantidad, precio) in lineas) {
        await elegir(tester, find.byType(DropdownMenu<Tela>), tela.nombre);
        await escribir(tester, campo('Precio'), precio);
        await escribir(tester, campo('Cantidad'), cantidad);
        await tocar(tester, find.text('Añadir'));
      }
      await tocar(tester, find.text('Guardar'));
      await esperarHasta(tester, find.text(snackOk));
      await esperarHasta(tester, tarjeta(changeFormatDate(DateTime.now())));
    }

    Future<List<Map<String, dynamic>>> ventasDe(Sucursal sucursal) => db
        .from('ventas')
        .select('id, total, ganancias')
        .eq('idsucursales', sucursal.id);

    testWidgets('registra la venta del día con su detalle', (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Venta telas');
      final tela = await datos.tela('Lino', compra: 15);
      await iniciarSesionDirecto();
      await montarApp(tester);

      await abrirVentas(tester, sucursal);
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.byType(DropdownMenu<Tela>));
      await elegir(tester, find.byType(DropdownMenu<Tela>), tela.nombre);
      await escribir(tester, campo('Precio'), '25');
      await escribir(tester, campo('Cantidad'), '3');
      await tocar(tester, find.text('Añadir'));
      expect(find.text('75.0 Bs'), findsOneWidget); // total del carrito
      await tocar(tester, find.text('Guardar'));
      await esperarHasta(tester, find.text(snackOk));
      await esperarHasta(tester, tarjeta(changeFormatDate(DateTime.now())));

      final ventas = await ventasDe(sucursal);
      expect(ventas, hasLength(1));
      expect(numero(ventas.single['total']), 75);
      expect(numero(ventas.single['ganancias']), 30); // (25-15)*3
      final detalles = await db
          .from('detalle_ventas')
          .select('idtelas, precio, cantidad, total')
          .eq('idventa', ventas.single['id']);
      expect(detalles, hasLength(1));
      expect(detalles.single['idtelas'], tela.id);
      expect(numero(detalles.single['cantidad']), 3);
      expect(numero(detalles.single['total']), 75);
    });

    testWidgets('una segunda venta el mismo día se suma a la venta del día',
        (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Dos ventas');
      final tela = await datos.tela('Seda');
      await iniciarSesionDirecto();
      await montarApp(tester);

      await abrirVentas(tester, sucursal);
      await venderDesdeUI(tester, [(tela, '2', '25')]);
      await venderDesdeUI(tester, [(tela, '1', '25')]);

      final ventas = await ventasDe(sucursal);
      expect(ventas, hasLength(1), reason: 'una venta por sucursal y día');
      expect(numero(ventas.single['total']), 75);
      final detalles = await db
          .from('detalle_ventas')
          .select('cantidad')
          .eq('idventa', ventas.single['id']);
      expect(detalles, hasLength(1), reason: 'misma tela y mismo precio');
      expect(numero(detalles.single['cantidad']), 3);
      expect(tarjeta(changeFormatDate(DateTime.now())), findsOneWidget);
    });

    testWidgets('el detalle permite borrar una línea y descuenta el total',
        (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Borrar linea');
      final lino = await datos.tela('Lino');
      final seda = await datos.tela('Seda');
      await iniciarSesionDirecto();
      await montarApp(tester);

      await abrirVentas(tester, sucursal);
      await venderDesdeUI(tester, [(lino, '2', '25'), (seda, '1', '30')]);
      expect(numero((await ventasDe(sucursal)).single['total']), 80);

      await tester.tap(tarjeta(changeFormatDate(DateTime.now())));
      final borrar = find.byIcon(Icons.delete_forever_rounded);
      await esperarHasta(tester, borrar);
      expect(borrar, findsNWidgets(2));
      await tester.tap(borrar.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));

      final idventa = (await ventasDe(sucursal)).single['id'];
      await esperarQue(() async {
        final filas = await db
            .from('detalle_ventas')
            .select('id')
            .eq('idventa', idventa);
        return filas.length == 1;
      }, descripcion: 'queda una sola línea');
      await esperarHasta(tester, find.byIcon(Icons.delete_forever_rounded));
      expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);

      // El total de la venta queda igual al de la línea que sobrevivió
      final restante = await db
          .from('detalle_ventas')
          .select('total')
          .eq('idventa', idventa)
          .single();
      await esperarQue(() async {
        final venta = (await ventasDe(sucursal)).single;
        return numero(venta['total']) == numero(restante['total']);
      }, descripcion: 'total de la venta descontado');
    });
  });
}
