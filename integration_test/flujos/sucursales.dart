import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';

import '../datos.dart';
import '../helpers.dart';

void sucursalesTests() {
  group('sucursales', () {
    testWidgets('crea una sucursal desde el formulario', (tester) async {
      final nombre = Datos().nombre('Sucursal nueva');
      await iniciarSesionDirecto();
      await montarApp(tester);

      await irDesdeMenu(tester, 'Sucursales');
      await tocar(tester, tarjeta('Agregar Sucusal'));
      expect(find.text('Crear Sucursal'), findsOneWidget);
      await escribir(tester, campo('Nombre'), nombre);
      await tocar(tester, find.text('Guardar'));
      await esperarHasta(tester, find.text(snackOk));
      await tester.scrollUntilVisible(tarjeta(nombre), 200,
          scrollable: listaVertical.first);

      final filas =
          await db.from('sucursales').select('activo').eq('nombre', nombre);
      expect(filas, hasLength(1));
      expect(filas.single['activo'], isTrue);
    });

    testWidgets('modifica el nombre y la da de baja (baja lógica)',
        (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Editar');
      final renombrada = datos.nombre('Renombrada');
      await iniciarSesionDirecto();
      await montarApp(tester);

      await irDesdeMenu(tester, 'Sucursales');
      await tocar(tester, tarjeta(sucursal.nombre));
      await esperarHasta(tester, find.text('Editar Sucursal'));
      await escribir(tester, campo('Nombre'), renombrada);
      await tocar(tester, find.text('Modificar'));
      await esperarHasta(tester, find.text(snackOk));
      await tester.scrollUntilVisible(tarjeta(renombrada), 200,
          scrollable: listaVertical.first);
      var fila = await db
          .from('sucursales')
          .select('nombre, activo')
          .eq('id', sucursal.id)
          .single();
      expect(fila['nombre'], renombrada);

      await tocar(tester, tarjeta(renombrada));
      await esperarHasta(tester, find.text('Editar Sucursal'));
      await tocar(tester, find.text('Eliminar'));
      await esperarHasta(tester, find.text(snackOk));

      // No se borra: queda con activo = false y sale de las grillas
      fila = await db
          .from('sucursales')
          .select('nombre, activo')
          .eq('id', sucursal.id)
          .single();
      expect(fila['activo'], isFalse);
      await tester.drag(listaVertical.first, const Offset(0, -5000));
      await tester.pumpAndSettle();
      expect(tarjeta(renombrada), findsNothing);
    });

    testWidgets(
        'la disponibilidad de telas limita lo que ofrece la venta de la '
        'sucursal', (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Disponibilidad');
      final ofrecida = await datos.tela('Ofrecida');
      final otra = await datos.tela('No ofrecida');
      await iniciarSesionDirecto();
      await montarApp(tester);

      await irDesdeMenu(tester, 'Sucursales');
      await tocar(tester, tarjeta(sucursal.nombre));
      await tocar(tester, find.text('Disponibilidad de telas'));
      await esperarHasta(tester, find.text('Disponibilidad de telas'));
      await tocar(tester, find.widgetWithText(SwitchListTile, ofrecida.nombre));
      await esperarQue(() async {
        final filas = await db
            .from('tela_sucursales')
            .select('activo')
            .eq('idsucursal', sucursal.id)
            .eq('idtela', ofrecida.id);
        return filas.isNotEmpty && filas.single['activo'] == true;
      }, descripcion: 'tela vinculada a la sucursal');

      await volver(tester);
      await volver(tester);
      await irDesdeMenu(tester, 'Venta telas');
      await tocar(tester, tarjeta(sucursal.nombre));
      await esperarHasta(tester, find.text('Ventas'));
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.byType(DropdownMenu<Tela>));
      await tester.tap(find.byType(DropdownMenu<Tela>));
      await tester.pumpAndSettle();

      expect(opcionDeMenu(ofrecida.nombre), findsWidgets);
      expect(opcionDeMenu(otra.nombre), findsNothing);
      await tester.tap(opcionDeMenu(ofrecida.nombre).last);
      await tester.pumpAndSettle();
    });
  });
}
