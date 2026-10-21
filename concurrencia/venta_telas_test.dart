@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:textiles_app/features/shared/clave_de_operacion.dart';

import 'datos.dart';
import 'dispositivos.dart';
import 'operaciones.dart';

/// Venta de telas desde varios dispositivos a la vez. Con el flujo de
/// Android e iOS (cabecera del día con su UNIQUE, líneas con
/// `registrar_detalle_venta`, totales con `incrementar_venta`) y con el del
/// Flutter (todo junto en `registrar_venta_telas`): nadie pierde lo que manda
/// otro, y con la misma clave de operación se aplica una sola vez.
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
      'venta del día creada por $cantidadDispositivos dispositivos a la vez: '
      'una gana, las demás reciben 23505 y recuperan esa misma venta',
      () async {
    for (var vuelta = 1; vuelta <= repeticiones; vuelta++) {
      final sucursal = await datos.sucursal();

      final resultados = await aLaVez(
          dispositivos, (i, d) => insertarVentaTelas(d, sucursal, fechaCC));
      final enVuelta = 'vuelta $vuelta: $resultados';

      final ganadoras = resultados.where((r) => r.ok).toList();
      expect(ganadoras, hasLength(1), reason: enVuelta);
      final id = ganadoras.single.valor!['id'];
      final perdedores = [
        for (var i = 0; i < resultados.length; i++)
          if (!resultados[i].ok) dispositivos[i],
      ];
      for (final r in resultados.where((r) => !r.ok)) {
        expect(r.error,
            isA<PostgrestException>().having((e) => e.code, 'code', '23505'),
            reason: 'UNIQUE (idsucursales, día) ($enVuelta)');
      }

      // Lo que hace VentasDatasourceImpl.createVenta al atrapar el 23505:
      // busca la venta del día y sigue con esa.
      final recuperadas = await aLaVez(
          perdedores, (i, d) => buscarVentaTelasDelDia(d, sucursal, fechaCC));
      expect(recuperadas.map((r) => r.valor?['id']).toSet(), {id},
          reason: 'recuperadas: $recuperadas ($enVuelta)');
      expect(await ventasTelasDelDia(db(), sucursal, fechaCC), hasLength(1),
          reason: enVuelta);
    }
  });

  test(
      'registrar_detalle_venta de la misma tela y precio desde '
      '$cantidadDispositivos dispositivos a la vez: una línea con todo sumado',
      () async {
    const precio = 25;
    const compra = 15;
    for (var vuelta = 1; vuelta <= repeticiones; vuelta++) {
      final sucursal = await datos.sucursal();
      final tela = await datos.tela(precio: precio, compra: compra);
      final venta = await insertarVentaTelas(db(), sucursal, fechaCC);

      // El dispositivo i vende (i+1) × 0,5 m: la línea no existe todavía y
      // todos compiten por crearla.
      final resultados = await aLaVez(
          dispositivos,
          (i, d) => registrarDetalleVenta(d,
              venta: venta['id'] as int,
              tela: tela,
              precio: precio,
              cantidad: (i + 1) / 2,
              compra: compra));
      final enVuelta = 'vuelta $vuelta: $resultados';
      expect(resultados.every((r) => r.ok), isTrue, reason: enVuelta);

      var metros = 0, total = 0, ganancias = 0; // en centavos
      for (var i = 0; i < dispositivos.length; i++) {
        metros += (i + 1) * 50;
        total += (i + 1) * 50 * precio;
        ganancias += (i + 1) * 50 * (precio - compra);
      }

      final lineas = await lineasVentaTelas(db(), venta['id'] as int);
      expect(lineas, hasLength(1), reason: enVuelta);
      final linea = lineas.single;
      expect(linea['idtelas'], tela, reason: enVuelta);
      expect(centavos(linea['cantidad']), metros, reason: enVuelta);
      expect(centavos(linea['total']), total, reason: enVuelta);
      expect(centavos(linea['ganancias']), ganancias, reason: enVuelta);
    }
  });

  test(
      'incrementar_venta con deltas desde $cantidadDispositivos dispositivos '
      'a la vez: los totales son la suma exacta', () async {
    const incrementosPorDispositivo = 5;
    // Deltas en centavos del incremento j del dispositivo i
    int deltaTotal(int i, int j) => 1235 + 100 * i + j;
    int deltaGanancias(int i, int j) => 410 + 10 * j;
    int deltaDescuento(int i, int j) => 5 * (i + 1);

    for (var vuelta = 1; vuelta <= repeticiones; vuelta++) {
      final sucursal = await datos.sucursal();
      final venta = await insertarVentaTelas(db(), sucursal, fechaCC);
      final id = venta['id'] as int;

      // Cada dispositivo registra varias ventas seguidas (como al confirmar
      // varias veces en el día) mientras los demás hacen lo mismo.
      final resultados = await aLaVez(dispositivos, (i, d) async {
        for (var j = 0; j < incrementosPorDispositivo; j++) {
          await incrementarVenta(d, id,
              total: deltaTotal(i, j) / 100,
              ganancias: deltaGanancias(i, j) / 100,
              descuento: deltaDescuento(i, j) / 100);
        }
      });
      final enVuelta = 'vuelta $vuelta: $resultados';
      expect(resultados.every((r) => r.ok), isTrue, reason: enVuelta);

      var total = 0, ganancias = 0, descuento = 0;
      for (var i = 0; i < dispositivos.length; i++) {
        for (var j = 0; j < incrementosPorDispositivo; j++) {
          total += deltaTotal(i, j);
          ganancias += deltaGanancias(i, j);
          descuento += deltaDescuento(i, j);
        }
      }

      final fila = await ventaTelas(db(), id);
      expect(centavos(fila['total']), total, reason: enVuelta);
      expect(centavos(fila['ganancias']), ganancias, reason: enVuelta);
      expect(centavos(fila['descuento']), descuento, reason: enVuelta);
    }
  });

  test(
      'registrar_venta_telas desde $cantidadDispositivos dispositivos a la vez '
      'en una sucursal sin venta del día: una venta, una línea con todo sumado '
      'y el total igual a la suma de las líneas', () async {
    const precio = 25;
    const compra = 15;
    for (var vuelta = 1; vuelta <= repeticiones; vuelta++) {
      final sucursal = await datos.sucursal();
      final tela = await datos.tela(precio: precio, compra: compra);

      // El dispositivo i vende (i+1) × 0,5 m con su propia clave y 0,0(i+1)
      // de descuento: compiten por crear la venta del día y la línea.
      final resultados = await aLaVez(
          dispositivos,
          (i, d) => registrarVentaTelas(d,
              sucursal: sucursal,
              tela: tela,
              precio: precio,
              cantidad: (i + 1) / 2,
              compra: compra,
              fecha: fechaCC,
              descuento: (i + 1) / 100,
              idOperacion: uuidV4()));
      final enVuelta = 'vuelta $vuelta: $resultados';
      expect(resultados.every((r) => r.ok), isTrue, reason: enVuelta);
      expect(resultados.map((r) => r.valor).toSet(), hasLength(1),
          reason: 'todos suman a la misma venta del día ($enVuelta)');

      var metros = 0, total = 0, ganancias = 0, descuento = 0; // en centavos
      for (var i = 0; i < dispositivos.length; i++) {
        metros += (i + 1) * 50;
        total += (i + 1) * 50 * precio;
        ganancias += (i + 1) * 50 * (precio - compra);
        descuento += i + 1;
      }

      final ventas = await ventasTelasDelDia(db(), sucursal, fechaCC);
      expect(ventas, hasLength(1), reason: enVuelta);
      final venta = ventas.single;
      final lineas = await lineasVentaTelas(db(), venta['id'] as int);
      expect(lineas, hasLength(1), reason: enVuelta);
      expect({
        'metros': centavos(lineas.single['cantidad']),
        'total de la línea': centavos(lineas.single['total']),
        'ganancias de la línea': centavos(lineas.single['ganancias']),
        'total de la venta': centavos(venta['total']),
        'ganancias de la venta': centavos(venta['ganancias']),
        'descuento de la venta': centavos(venta['descuento']),
      }, {
        'metros': metros,
        'total de la línea': total,
        'ganancias de la línea': ganancias,
        'total de la venta': total,
        'ganancias de la venta': ganancias,
        'descuento de la venta': descuento,
      }, reason: enVuelta);
    }
  });

  test(
      'el mismo envío (misma clave) desde $cantidadDispositivos dispositivos a '
      'la vez —reintentos que se cruzan—: se aplica una sola vez y todos '
      'reciben la misma venta', () async {
    const precio = 25;
    const compra = 15;
    for (var vuelta = 1; vuelta <= repeticiones; vuelta++) {
      final sucursal = await datos.sucursal();
      final tela = await datos.tela(precio: precio, compra: compra);
      final clave = uuidV4();

      final resultados = await aLaVez(
          dispositivos,
          (i, d) => registrarVentaTelas(d,
              sucursal: sucursal,
              tela: tela,
              precio: precio,
              cantidad: 2,
              compra: compra,
              fecha: fechaCC,
              descuento: 1,
              idOperacion: clave));
      final enVuelta = 'vuelta $vuelta: $resultados';
      expect(resultados.every((r) => r.ok), isTrue, reason: enVuelta);
      expect(resultados.map((r) => r.valor).toSet(), hasLength(1),
          reason: enVuelta);

      final venta = (await ventasTelasDelDia(db(), sucursal, fechaCC)).single;
      final lineas = await lineasVentaTelas(db(), venta['id'] as int);
      expect({
        'líneas': lineas.length,
        'metros': centavos(lineas.single['cantidad']),
        'total de la venta': centavos(venta['total']),
        'descuento de la venta': centavos(venta['descuento']),
      }, {
        'líneas': 1,
        'metros': 200,
        'total de la venta': 2 * precio * 100,
        'descuento de la venta': 100,
      }, reason: enVuelta);
    }
  });
}
