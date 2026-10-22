import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';

import '../datos.dart';
import '../helpers.dart';

void telasTests() {
  group('telas', () {
    Future<void> buscarTela(WidgetTester tester, String nombre) async {
      await irDesdeMenu(tester, 'Telas');
      await esperarHasta(tester, find.byIcon(Icons.add));
      await escribir(tester, find.byType(TextField).first, nombre);
      expect(textoFijo(nombre), findsOneWidget);
    }

    testWidgets('crea una tela desde el formulario', (tester) async {
      final nombre = Datos().nombre('Tela nueva');
      await iniciarSesionDirecto();
      await montarApp(tester);

      await irDesdeMenu(tester, 'Telas');
      await esperarHasta(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.text('Crear Tela'));
      await escribir(tester, campo('Nombre'), nombre);
      await escribir(tester, campo('Precio X Menor'), '25');
      await escribir(tester, campo('Precio X Mayor'), '20');
      await escribir(tester, campo('Precio X Rollo'), '18');
      await escribir(tester, campo('Precio Compra'), '15');
      await tocar(tester, find.text('Guardar'));
      await esperarHasta(tester, find.text(snackOk));

      // De vuelta en el listado (se recarga al volver): buscarla
      await esperarHasta(tester, find.byIcon(Icons.add));
      await escribir(tester, find.byType(TextField).first, nombre);
      expect(textoFijo(nombre), findsOneWidget);

      final telas = await db
          .from('telas')
          .select('precxmen, precxmay, precxrollo, precxcompra, activo')
          .eq('nombre', nombre);
      expect(telas, hasLength(1));
      expect(numero(telas.single['precxmen']), 25);
      expect(numero(telas.single['precxmay']), 20);
      expect(numero(telas.single['precxrollo']), 18);
      expect(numero(telas.single['precxcompra']), 15);
      expect(telas.single['activo'], isTrue);
    });

    testWidgets(
        'modifica el precio y al desactivarla deja de ofrecerse en la venta',
        (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Tela inactiva');
      final tela = await datos.tela('Editar');
      await iniciarSesionDirecto();
      await montarApp(tester);

      await buscarTela(tester, tela.nombre);
      await tester.tap(find.byTooltip('Modificar'));
      await esperarHasta(tester, find.text('Editar Tela'));
      await escribir(tester, campo('Precio X Menor'), '30');
      await tocar(tester, find.widgetWithText(SwitchListTile, 'Activo'));
      await tocar(tester, find.text('Modificar'));
      await esperarHasta(tester, find.text(snackOk));

      final fila = await db
          .from('telas')
          .select('precxmen, activo')
          .eq('id', tela.id)
          .single();
      expect(numero(fila['precxmen']), 30);
      expect(fila['activo'], isFalse);
      // El listado de gestión la sigue mostrando, marcada
      await esperarHasta(tester, find.text('Inactivo'));

      await irDesdeMenu(tester, 'Venta telas');
      await tocar(tester, tarjeta(sucursal.nombre));
      await esperarHasta(tester, find.text('Ventas'));
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.byType(DropdownMenu<Tela>));
      await tester.tap(find.byType(DropdownMenu<Tela>));
      await tester.pumpAndSettle();
      expect(opcionDeMenu(tela.nombre), findsNothing);
    });

    testWidgets('vincula y desvincula un color de la tela', (tester) async {
      final datos = Datos();
      final tela = await datos.tela('Con color');
      final color = await datos.color('Turquesa', hex: '1ABC9C');
      await iniciarSesionDirecto();
      await montarApp(tester);

      Future<bool?> vinculado() async {
        final filas = await db
            .from('tela_colores')
            .select('activo')
            .eq('idtela', tela.id)
            .eq('idcolor', color.id);
        return filas.isEmpty ? null : filas.single['activo'] as bool;
      }

      await buscarTela(tester, tela.nombre);
      await tester.tap(find.text('Colores'));
      await esperarHasta(tester, find.text(tela.nombre));
      final interruptor = find.widgetWithText(SwitchListTile, color.nombre);
      await esperarHasta(tester, interruptor);

      await tocar(tester, interruptor);
      await esperarQue(() async => await vinculado() == true,
          descripcion: 'color vinculado a la tela');
      await tocar(tester, interruptor);
      await esperarQue(() async => await vinculado() == false,
          descripcion: 'color desvinculado (activo = false)');
    });
  });
}
