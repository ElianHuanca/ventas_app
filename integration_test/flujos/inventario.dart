import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';

import '../datos.dart';
import '../helpers.dart';

void inventarioTests() {
  group('inventario', () {
    Future<void> abrirInventario(WidgetTester tester, Sucursal sucursal) async {
      await irDesdeMenu(tester, 'Inventario');
      await tocar(tester, tarjeta(sucursal.nombre));
      await esperarHasta(tester, find.textContaining('Faltan ('));
    }

    /// La tarjeta de la fila cuyo texto contiene [texto] (el aplique o, si
    /// hay varias del mismo aplique, el color).
    Finder fila(String texto) => find.ancestor(
        of: find.textContaining(texto), matching: find.byType(Card));

    Future<void> verFila(WidgetTester tester, String texto) async {
      await tester.scrollUntilVisible(fila(texto), 200,
          scrollable: listaVertical.first);
      await tester.pumpAndSettle();
    }

    /// La pantalla avisa cuando estima con las otras sucursales (la tienda no
    /// vendió nada propio en la ventana).
    final avisoEstimada = find.textContaining('se estima con lo que venden');

    testWidgets(
        'un aplique que se vendió y quedó corto aparece en Faltan con cuánto '
        'hacer, y la lista copiada lo lleva', (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Inventario');
      final aplique = await datos.aplique('Mariposa');
      final color = await datos.color('Fucsia', hex: 'E91E63');
      await datos.vincularColor(aplique, color);
      await datos.fabricar(sucursal, aplique, color, 10);
      await datos.venderApliques(sucursal, aplique, color, 8, 12);
      expect(await stockDe(sucursal, aplique, color), 2);
      await iniciarSesionDirecto();
      await montarApp(tester);

      await abrirInventario(tester, sucursal);
      await esperarHasta(tester, find.text('Faltan (1)'));
      await verFila(tester, aplique.nombre);
      // 8 vendidas en 4 semanas: mínimo = ceil(8 × 2,5 / 4) = 5. Con stock 2
      // falta, y se pide hasta el doble del mínimo: 2 × 5 − 2 = 8
      final mariposa = fila(aplique.nombre);
      expect(find.descendant(of: mariposa, matching: find.text('Hacer')),
          findsOneWidget);
      expect(find.descendant(of: mariposa, matching: find.text('8')),
          findsOneWidget);
      expect(
          find.descendant(
              of: mariposa, matching: find.textContaining('Quedan 2')),
          findsOneWidget);
      expect(
          find.descendant(
              of: mariposa, matching: find.textContaining('mínimo 5')),
          findsOneWidget);
      expect(find.text('Hacer 8 en total'), findsOneWidget);
      expect(avisoEstimada, findsNothing,
          reason: 'la sucursal vendió: usa sus propias ventas');

      await tester.tap(find.byTooltip('Copiar lista'));
      await esperarHasta(
          tester, find.text('Lista copiada: pegala en WhatsApp'));
      final copiado = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      expect(copiado, isNotNull);
      expect(copiado, contains(sucursal.nombre));
      final linea = copiado!
          .split('\n')
          .where((l) => l.contains(aplique.nombre))
          .toList();
      expect(linea, hasLength(1), reason: copiado);
      expect(linea.single, contains(color.nombre));
      expect(linea.single, contains('hacer *8*'));
      expect(copiado, contains('Total a hacer: 8'));
    });

    testWidgets(
        'un aplique fabricado sin ventas no está en Faltan pero sí en Todos',
        (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Inventario sin ventas');
      final aplique = await datos.aplique('Estrella');
      final vendido = await datos.color('Rojo', hex: 'C0392B');
      final quieto = await datos.color('Celeste', hex: '5DADE2');
      await datos.vincularColor(aplique, vendido);
      await datos.vincularColor(aplique, quieto);
      await datos.fabricar(sucursal, aplique, vendido, 10);
      await datos.fabricar(sucursal, aplique, quieto, 6);
      // Una venta propia (de otro color): la sucursal tiene historial y no se
      // estima con lo que venden las otras sucursales de la base. 1 vendida:
      // mínimo ceil(1 × 2,5 / 4) = 1, y con stock 9 no falta
      await datos.venderApliques(sucursal, aplique, vendido, 1, 12);
      await iniciarSesionDirecto();
      await montarApp(tester);

      await abrirInventario(tester, sucursal);
      await esperarHasta(tester, find.text('Faltan (0)'));
      expect(find.text('No falta nada'), findsOneWidget);
      expect(find.text(aplique.nombre), findsNothing);
      expect(avisoEstimada, findsNothing,
          reason: 'la sucursal vendió: usa sus propias ventas');
      expect(
          tester
              .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.copy_rounded))
              .onPressed,
          isNull,
          reason: 'sin faltantes no hay lista para copiar');

      await tester.tap(find.text('Todos (2)'));
      await tester.pumpAndSettle();
      await verFila(tester, quieto.nombre);
      final celeste = fila(quieto.nombre);
      expect(
          find.descendant(
              of: celeste,
              matching: find.textContaining('sin ventas en 4 semanas')),
          findsOneWidget);
      expect(
          find.descendant(
              of: celeste, matching: find.textContaining('Quedan 6')),
          findsOneWidget);
      expect(find.descendant(of: celeste, matching: find.text('Hacer')),
          findsNothing);

      await verFila(tester, vendido.nombre);
      final rojo = fila(vendido.nombre);
      expect(
          find.descendant(of: rojo, matching: find.textContaining('Quedan 9')),
          findsOneWidget);
      expect(find.descendant(of: rojo, matching: find.text('Hacer')),
          findsNothing);
    });
  });
}
