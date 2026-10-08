import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';

import '../datos.dart';
import '../helpers.dart';

void apliquesTests() {
  group('apliques', () {
    Future<void> buscarAplique(WidgetTester tester, String nombre) async {
      await esperarHasta(tester, find.byIcon(Icons.add));
      await escribir(tester, find.byType(TextField).first, nombre);
      expect(textoFijo(nombre), findsOneWidget);
    }

    testWidgets('crea un aplique, lo modifica y lo desactiva', (tester) async {
      final nombre = Datos().nombre('Estrella');
      await iniciarSesionDirecto();
      await montarApp(tester);

      await irDesdeMenu(tester, 'Apliques');
      await esperarHasta(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.text('Crear Aplique'));
      await escribir(tester, campo('Nombre'), nombre);
      await escribir(tester, campo('Ancho (cm)'), '4');
      await escribir(tester, campo('Alto (cm)'), '3');
      await escribir(tester, campo('Costo de fabricación'), '5');
      await tocar(tester, find.text('Guardar'));
      await esperarHasta(tester, find.text(snackOk));

      final creado = await db
          .from('apliques')
          .select('id, ancho_cm, alto_cm, costo_fabricacion, activo')
          .eq('nombre', nombre);
      expect(creado, hasLength(1));
      expect(numero(creado.single['ancho_cm']), 4);
      expect(numero(creado.single['alto_cm']), 3);
      expect(numero(creado.single['costo_fabricacion']), 5);
      expect(creado.single['activo'], isTrue);

      await buscarAplique(tester, nombre);
      expect(find.text('4.0 × 3.0 cm'), findsOneWidget);
      await tester.tap(find.text('Modificar'));
      await esperarHasta(tester, find.text('Editar Aplique'));
      await escribir(tester, campo('Costo de fabricación'), '7.5');
      await tocar(tester, find.widgetWithText(SwitchListTile, 'Activo'));
      await tocar(tester, find.text('Modificar'));
      await esperarHasta(tester, find.text(snackOk));

      final fila = await db
          .from('apliques')
          .select('costo_fabricacion, activo')
          .eq('id', creado.single['id'])
          .single();
      expect(numero(fila['costo_fabricacion']), 7.5);
      expect(fila['activo'], isFalse);
    });

    testWidgets(
        'deshabilitar un color del aplique lo saca de Fabricación y de la '
        'venta', (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Colores aplique');
      final aplique = await datos.aplique('Corazon');
      final rojo = await datos.color('Rojo', hex: 'E74C3C');
      final azul = await datos.color('Azul', hex: '3498DB');
      await datos.vincularColor(aplique, rojo);
      await datos.vincularColor(aplique, azul);
      // Con stock: antes del arreglo la venta seguía ofreciendo el color
      await datos.fabricar(sucursal, aplique, rojo, 5);
      await datos.fabricar(sucursal, aplique, azul, 5);
      await iniciarSesionDirecto();
      await montarApp(tester);

      // Gestión: Apliques → Colores → apagar Azul
      await irDesdeMenu(tester, 'Apliques');
      await buscarAplique(tester, aplique.nombre);
      await tester.tap(find.text('Colores'));
      final interruptorAzul = find.widgetWithText(SwitchListTile, azul.nombre);
      await esperarHasta(tester, interruptorAzul);
      await tocar(tester, interruptorAzul);
      await esperarQue(() async {
        final filas = await db
            .from('aplique_colores')
            .select('activo')
            .eq('idaplique', aplique.id)
            .eq('idcolor', azul.id);
        return filas.single['activo'] == false;
      }, descripcion: 'Azul desvinculado del aplique');
      await volver(tester);

      // Fabricación: solo Rojo
      await irDesdeMenu(tester, 'Fabricación');
      await tocar(tester, tarjeta(sucursal.nombre));
      await esperarHasta(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.byType(DropdownMenu<Aplique>));
      await elegir(tester, find.byType(DropdownMenu<Aplique>), aplique.nombre);
      await tester.tap(find.byType(DropdownMenu<ColorItem>));
      await tester.pumpAndSettle();
      expect(opcionDeMenu(rojo.nombre), findsWidgets);
      expect(opcionDeMenu(azul.nombre), findsNothing);
      await tester.tap(opcionDeMenu(rojo.nombre).last);
      await tester.pumpAndSettle();

      // Venta de apliques: solo Rojo, aunque Azul tiene stock
      await volver(tester);
      await volver(tester);
      await irDesdeMenu(tester, 'Venta apliques');
      await tocar(tester, tarjeta(sucursal.nombre));
      await esperarHasta(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.byType(DropdownMenu<Aplique>));
      await elegir(tester, find.byType(DropdownMenu<Aplique>), aplique.nombre);
      await tester.tap(find.byType(DropdownMenu<StockAplique>));
      await tester.pumpAndSettle();
      expect(opcionDeMenu(rojo.nombre), findsWidgets);
      expect(opcionDeMenu(azul.nombre), findsNothing);
      await tester.tap(opcionDeMenu(rojo.nombre).last);
      await tester.pumpAndSettle();
    });
  });
}
