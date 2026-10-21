@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'datos.dart';
import 'dispositivos.dart';
import 'operaciones.dart';

/// Fabricación (RPC `registrar_produccion`) desde varios dispositivos a la
/// vez: una cabecera por sucursal+día, una línea por aplique+color que
/// acumula, y el stock sube exactamente lo fabricado.
void main() {
  var dispositivos = <SupabaseClient>[];
  late DatosCC datos;
  SupabaseClient db() => dispositivos.first;

  setUpAll(() async {
    dispositivos = await abrirDispositivos();
    datos = DatosCC(db());
  });

  tearDownAll(() async {
    try {
      if (dispositivos.isNotEmpty) await datos.darDeBaja();
    } finally {
      await cerrarDispositivos(dispositivos);
    }
  });

  test(
      'mismo aplique+color+sucursal+día desde $cantidadDispositivos '
      'dispositivos a la vez: una cabecera, una línea y el stock exacto',
      () async {
    for (var vuelta = 1; vuelta <= repeticiones; vuelta++) {
      // Sucursal nueva: los dispositivos compiten por crear la cabecera del
      // día, la línea y la fila de inventario.
      final p = await datos.apliqueEnSucursalNueva();

      final resultados = await aLaVez(
          dispositivos,
          (i, d) => fabricar(d,
              sucursal: p.sucursal,
              aplique: p.aplique,
              color: p.color,
              cantidad: i + 1,
              fecha: fechaCC));
      final enVuelta = 'vuelta $vuelta: $resultados';
      expect(resultados.every((r) => r.ok), isTrue, reason: enVuelta);
      final fabricado = [for (var i = 0; i < dispositivos.length; i++) i + 1]
          .fold<int>(0, (s, c) => s + c);

      final producciones = await produccionesDelDia(db(), p.sucursal, fechaCC);
      expect(producciones, hasLength(1), reason: enVuelta);
      final produccion = producciones.single;
      expect(resultados.map((r) => r.valor).toSet(), {produccion['id']},
          reason: 'todos suman a la misma producción ($enVuelta)');

      final lineas = await lineasProduccion(db(), produccion['id'] as int);
      expect(lineas, hasLength(1), reason: enVuelta);
      expect(lineas.single['idaplique'], p.aplique, reason: enVuelta);
      expect(lineas.single['idcolor'], p.color, reason: enVuelta);
      expect(numero(lineas.single['cantidad']), fabricado, reason: enVuelta);
      expect(await stockDe(db(), p), fabricado, reason: enVuelta);
    }
  });

  test(
      'fabricar y vender el mismo aplique+color a la vez: el stock final es '
      'lo que había + lo fabricado - lo vendido', () async {
    const stockInicial = 10;
    const fabricaCadaUno = 5;
    for (var vuelta = 1; vuelta <= repeticiones; vuelta++) {
      final p = await datos.apliqueEnSucursalNueva();
      await fabricar(db(),
          sucursal: p.sucursal,
          aplique: p.aplique,
          color: p.color,
          cantidad: stockInicial,
          fecha: fechaCC);

      // Los pares venden 1 unidad (alcanza el stock inicial aunque ninguna
      // fabricación haya entrado todavía); los impares fabrican 5.
      final resultados = await aLaVez(
          dispositivos,
          (i, d) => i.isEven
              ? venderApliques(d,
                  sucursal: p.sucursal,
                  aplique: p.aplique,
                  color: p.color,
                  cantidad: 1,
                  precio: 10,
                  fecha: fechaCC)
              : fabricar(d,
                  sucursal: p.sucursal,
                  aplique: p.aplique,
                  color: p.color,
                  cantidad: fabricaCadaUno,
                  fecha: fechaCC));
      final enVuelta = 'vuelta $vuelta: $resultados';
      expect(resultados.every((r) => r.ok), isTrue, reason: enVuelta);
      final vendido = (dispositivos.length + 1) ~/ 2;
      final fabricado = dispositivos.length ~/ 2 * fabricaCadaUno;

      expect(await stockDe(db(), p), stockInicial + fabricado - vendido,
          reason: enVuelta);
      final venta =
          (await ventasApliquesDelDia(db(), p.sucursal, fechaCC)).single;
      final lineasVenta = await lineasVentaApliques(db(), venta['id'] as int);
      expect(numero(lineasVenta.single['cantidad']), vendido, reason: enVuelta);
      final produccion =
          (await produccionesDelDia(db(), p.sucursal, fechaCC)).single;
      final lineasProd = await lineasProduccion(db(), produccion['id'] as int);
      expect(numero(lineasProd.single['cantidad']), stockInicial + fabricado,
          reason: enVuelta);
    }
  });
}
