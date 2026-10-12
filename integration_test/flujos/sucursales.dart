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
      await tocar(tester, tarjeta('Agregar Sucursal'));
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

    testWidgets(
        'quitar una tela de la sucursal la saca de la venta; sin ninguna '
        'activa vuelve a ofrecer todo el catálogo', (tester) async {
      final datos = Datos();
      final sucursal = await datos.sucursal('Quitar tela');
      final queda = await datos.tela('Queda');
      final quitada = await datos.tela('Quitada');
      await datos.ofrecerTela(sucursal, queda);
      await datos.ofrecerTela(sucursal, quitada);
      await iniciarSesionDirecto();
      await montarApp(tester);

      Future<bool?> ofrecida(Tela tela) async {
        final filas = await db
            .from('tela_sucursales')
            .select('activo')
            .eq('idsucursal', sucursal.id)
            .eq('idtela', tela.id);
        return filas.isEmpty ? null : filas.single['activo'] as bool;
      }

      Future<void> quitarDeLaSucursal(Tela tela) async {
        await irDesdeMenu(tester, 'Sucursales');
        await tocar(tester, tarjeta(sucursal.nombre));
        await tocar(tester, find.text('Disponibilidad de telas'));
        final interruptor = find.widgetWithText(SwitchListTile, tela.nombre);
        await esperarHasta(tester, interruptor);
        expect(tester.widget<SwitchListTile>(interruptor).value, isTrue);
        await tocar(tester, interruptor);
        await esperarQue(() async => await ofrecida(tela) == false,
            descripcion: '${tela.nombre} quitada (activo = false)');
        await volver(tester);
        await volver(tester);
      }

      /// Abre el selector de telas del registro de venta de la sucursal.
      Future<void> abrirSelectorDeVenta() async {
        await irDesdeMenu(tester, 'Venta telas');
        await tocar(tester, tarjeta(sucursal.nombre));
        await esperarHasta(tester, find.text('Ventas'));
        await tester.tap(find.byIcon(Icons.add));
        await esperarHasta(tester, find.byType(DropdownMenu<Tela>));
        await tester.tap(find.byType(DropdownMenu<Tela>));
        await tester.pumpAndSettle();
      }

      /// Cierra el selector eligiendo [tela] y vuelve al inicio.
      Future<void> cerrarSelectorDeVenta(Tela tela) async {
        await tester.tap(opcionDeMenu(tela.nombre).last);
        await tester.pumpAndSettle();
        await volver(tester);
        await volver(tester);
      }

      await quitarDeLaSucursal(quitada);
      expect(await ofrecida(queda), isTrue, reason: 'la otra no se toca');
      await abrirSelectorDeVenta();
      expect(opcionDeMenu(queda.nombre), findsWidgets);
      expect(opcionDeMenu(quitada.nombre), findsNothing);
      await cerrarSelectorDeVenta(queda);

      // Sin vínculos activos rige la regla de transición: todo el catálogo
      await quitarDeLaSucursal(queda);
      await abrirSelectorDeVenta();
      expect(opcionDeMenu(queda.nombre), findsWidgets);
      expect(opcionDeMenu(quitada.nombre), findsWidgets);
      await tester.tap(opcionDeMenu(quitada.nombre).last);
      await tester.pumpAndSettle();

      final filas = await db
          .from('tela_sucursales')
          .select('activo')
          .eq('idsucursal', sucursal.id);
      expect(filas, hasLength(2), reason: 'baja lógica, no se borran');
      expect(filas.every((f) => f['activo'] == false), isTrue);
    });
  });
}
