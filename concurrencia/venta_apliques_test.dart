@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'datos.dart';
import 'dispositivos.dart';
import 'operaciones.dart';

/// Venta de apliques (RPC `crear_venta_apliques`) desde varios dispositivos a
/// la vez: el stock se descuenta en la misma transacción que la venta, así
/// que nunca puede venderse más de lo que hay.
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
      'última unidad: de $cantidadDispositivos dispositivos vendiendo 1 a la '
      'vez solo venden los que tienen stock y el stock queda en 0', () async {
    const stockInicial = 3;
    for (var vuelta = 1; vuelta <= repeticiones; vuelta++) {
      final p = await datos.apliqueEnSucursalNueva();
      await fabricar(db(),
          sucursal: p.sucursal,
          aplique: p.aplique,
          color: p.color,
          cantidad: stockInicial,
          fecha: fechaCC);

      // Cada dispositivo vende a un precio propio (10, 11, …): así cada línea
      // de la venta del día dice quién vendió.
      final resultados = await aLaVez(
          dispositivos,
          (i, d) => venderApliques(d,
              sucursal: p.sucursal,
              aplique: p.aplique,
              color: p.color,
              cantidad: 1,
              precio: 10 + i,
              fecha: fechaCC));
      final enVuelta = 'vuelta $vuelta: $resultados';

      final vendieron = [
        for (var i = 0; i < resultados.length; i++)
          if (resultados[i].ok) i,
      ];
      expect(vendieron, hasLength(stockInicial), reason: enVuelta);
      for (final r in resultados.where((r) => !r.ok)) {
        expect(
            r.error,
            isA<PostgrestException>()
                .having((e) => e.hint, 'hint', 'stock_insuficiente'),
            reason: enVuelta);
      }

      expect(await stockDe(db(), p), 0, reason: enVuelta);
      final ventas = await ventasApliquesDelDia(db(), p.sucursal, fechaCC);
      expect(ventas, hasLength(1), reason: enVuelta);
      final venta = ventas.single;
      expect(resultados.where((r) => r.ok).map((r) => r.valor).toSet(),
          {venta['id']},
          reason: enVuelta);

      final lineas = await lineasVentaApliques(db(), venta['id'] as int);
      expect(lineas.map((l) => numero(l['precio'])).toSet(),
          {for (final i in vendieron) 10.0 + i},
          reason: 'solo quedan las líneas de los que vendieron ($enVuelta)');
      expect(lineas.fold<double>(0, (s, l) => s + numero(l['cantidad'])),
          stockInicial,
          reason: enVuelta);
      expect(centavos(venta['total']),
          vendieron.fold<int>(0, (s, i) => s + (10 + i) * 100),
          reason: 'el total no suma las ventas que fallaron ($enVuelta)');
    }
  });

  test(
      'primera venta del día desde $cantidadDispositivos dispositivos a la '
      'vez: una sola venta con total, ganancias y descuento sumados', () async {
    const stockInicial = 1000;
    const precio = 20;
    const costo = 5;
    for (var vuelta = 1; vuelta <= repeticiones; vuelta++) {
      final p = await datos.apliqueEnSucursalNueva(costo: costo);
      await fabricar(db(),
          sucursal: p.sucursal,
          aplique: p.aplique,
          color: p.color,
          cantidad: stockInicial,
          fecha: fechaCC);
      expect(await ventasApliquesDelDia(db(), p.sucursal, fechaCC), isEmpty,
          reason: 'la sucursal es nueva: no tiene venta del día');

      // El dispositivo i vende i+1 unidades del mismo aplique+color+precio
      // (todas van a la misma línea) con i × 0,50 de descuento.
      final resultados = await aLaVez(
          dispositivos,
          (i, d) => venderApliques(d,
              sucursal: p.sucursal,
              aplique: p.aplique,
              color: p.color,
              cantidad: i + 1,
              precio: precio,
              costo: costo,
              descuento: i * 50 / 100,
              fecha: fechaCC));
      final enVuelta = 'vuelta $vuelta: $resultados';
      expect(resultados.every((r) => r.ok), isTrue, reason: enVuelta);

      var unidades = 0, totalLineas = 0, ganancias = 0, descuento = 0;
      for (var i = 0; i < dispositivos.length; i++) {
        unidades += i + 1;
        totalLineas += (i + 1) * precio * 100;
        ganancias += (i + 1) * (precio - costo) * 100;
        descuento += i * 50;
      }

      final ventas = await ventasApliquesDelDia(db(), p.sucursal, fechaCC);
      expect(ventas, hasLength(1), reason: enVuelta);
      final venta = ventas.single;
      expect(resultados.map((r) => r.valor).toSet(), {venta['id']},
          reason: 'todos suman a la misma venta ($enVuelta)');
      expect(centavos(venta['total']), totalLineas - descuento,
          reason: enVuelta);
      expect(centavos(venta['ganancias']), ganancias, reason: enVuelta);
      expect(centavos(venta['descuento']), descuento, reason: enVuelta);

      final lineas = await lineasVentaApliques(db(), venta['id'] as int);
      expect(lineas, hasLength(1), reason: enVuelta);
      expect(numero(lineas.single['cantidad']), unidades, reason: enVuelta);
      expect(centavos(lineas.single['total']), totalLineas, reason: enVuelta);
      expect(centavos(lineas.single['ganancias']), ganancias, reason: enVuelta);
      expect(await stockDe(db(), p), stockInicial - unidades, reason: enVuelta);
    }
  });
}
