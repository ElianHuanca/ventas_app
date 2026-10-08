import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../datos.dart';
import '../helpers.dart';

void coloresTests() {
  group('colores', () {
    testWidgets('crea, renombra y da de baja un color', (tester) async {
      final datos = Datos();
      final nombre = datos.nombre('Coral');
      final renombrado = datos.nombre('Coral claro');
      await iniciarSesionDirecto();
      await montarApp(tester);

      await irDesdeMenu(tester, 'Colores');
      await esperarHasta(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.text('Crear Color'));
      await escribir(tester, campo('Nombre'), nombre);
      await escribir(tester, campo('Hex (ej: C0392B)'), '#ff7f50');
      await tocar(tester, find.text('Guardar'));
      await esperarHasta(tester, find.text(snackOk));

      // El hex se guarda normalizado (sin # y en mayúsculas)
      final creado =
          await db.from('colores').select('id, hex').eq('nombre', nombre);
      expect(creado, hasLength(1));
      expect(creado.single['hex'], 'FF7F50');
      final id = creado.single['id'];

      await esperarHasta(tester, find.byIcon(Icons.add));
      await tocarHasta(tester, find.text(nombre), find.text('Editar Color'));
      await escribir(tester, campo('Nombre'), renombrado);
      await tocar(tester, find.text('Modificar'));
      await esperarHasta(tester, find.text(snackOk));
      var fila = await db
          .from('colores')
          .select('nombre, activo')
          .eq('id', id)
          .single();
      expect(fila['nombre'], renombrado);

      await esperarHasta(tester, find.byIcon(Icons.add));
      await tocarHasta(
          tester, find.text(renombrado), find.text('Editar Color'));
      await tocar(tester, find.text('Eliminar'));
      await esperarHasta(tester, find.text(snackOk));
      fila = await db
          .from('colores')
          .select('nombre, activo')
          .eq('id', id)
          .single();
      expect(fila['activo'], isFalse, reason: 'baja lógica, no se borra');
    });

    testWidgets('no guarda un color con hex inválido', (tester) async {
      final nombre = Datos().nombre('Hex malo');
      await iniciarSesionDirecto();
      await montarApp(tester);

      await irDesdeMenu(tester, 'Colores');
      await esperarHasta(tester, find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.text('Crear Color'));
      await escribir(tester, campo('Nombre'), nombre);
      await escribir(tester, campo('Hex (ej: C0392B)'), 'XYZ');
      await tocar(tester, find.text('Guardar'));

      await esperarHasta(tester, find.text('Hubo un error'));
      expect(find.text('Crear Color'), findsOneWidget);
      final filas = await db.from('colores').select('id').eq('nombre', nombre);
      expect(filas, isEmpty);
    });
  });
}
