import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';

import 'red_con_fallas.dart';

/// La red con fallas en sí, contra un servidor falso (sin base): que cada
/// falla cae donde dice y que la respuesta perdida sí llega al servidor.
void main() {
  late List<http.Request> recibidos;
  late RedConFallas red;

  setUp(() {
    recibidos = [];
    red = RedConFallas(interno: MockClient((pedido) async {
      recibidos.add(pedido);
      return http.Response('{"ok": true}', 200);
    }));
    addTearDown(red.close);
  });

  final base = Uri.parse('http://127.0.0.1:54321/rest/v1');
  Future<http.Response> rpc(String nombre, [Map<String, Object?>? params]) =>
      red.post(Uri.parse('$base/rpc/$nombre'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(params ?? {}));
  Future<http.Response> leer(String tabla) =>
      red.get(Uri.parse('$base/$tabla?select=*'));

  final errorDeRed = throwsA(isA<http.ClientException>());

  test('sin fallas entrega todo y lo registra', () async {
    expect((await rpc('crear_venta_apliques')).statusCode, 200);
    expect((await leer('ventas')).body, '{"ok": true}');
    expect(recibidos, hasLength(2));
    expect(red.entregadas, ['rpc/crear_venta_apliques', 'ventas']);
  });

  test(
      'respuesta perdida: el pedido llega al servidor y la app recibe un '
      'error de conexión', () async {
    red.perderRespuesta();
    await expectLater(rpc('registrar_produccion'), errorDeRed);
    expect(recibidos, hasLength(1));
    expect(red.perdidas, ['rpc/registrar_produccion']);
    expect(red.registro.single.status, 200);

    // Se gastó: el siguiente pasa.
    expect((await rpc('registrar_produccion')).statusCode, 200);
  });

  test('sin conexión: el pedido no sale y dura hasta restablecer', () async {
    red.cortar();
    await expectLater(rpc('incrementar_venta'), errorDeRed);
    await expectLater(leer('ventas'), errorDeRed);
    expect(recibidos, isEmpty);
    expect(red.cortadas, ['rpc/incrementar_venta', 'ventas']);
    expect(red.llegaron, isEmpty);

    red.restablecer();
    expect((await leer('ventas')).statusCode, 200);
  });

  test('Cuando.rpc solo alcanza a esa RPC y se gasta después de veces',
      () async {
    red.perderRespuesta(cuando: Cuando.rpc('incrementar_venta'), veces: 2);
    expect((await rpc('registrar_detalle_venta')).statusCode, 200);
    await expectLater(rpc('incrementar_venta'), errorDeRed);
    await expectLater(rpc('incrementar_venta'), errorDeRed);
    expect((await rpc('incrementar_venta')).statusCode, 200);
    expect(red.perdidas, ['rpc/incrementar_venta', 'rpc/incrementar_venta']);
    expect(recibidos, hasLength(4));
  });

  test('Cuando.tabla filtra por tabla y método', () async {
    red.cortar(cuando: Cuando.tabla('detalle_ventas', metodo: 'delete'));
    expect((await leer('detalle_ventas')).statusCode, 200);
    await expectLater(
        red.delete(Uri.parse('$base/detalle_ventas?id=eq.1')), errorDeRed);
    expect(
        (await red.delete(Uri.parse('$base/ventas?id=eq.1'))).statusCode, 200);
    expect(red.cortadas, ['detalle_ventas']);
  });

  test('Cuando.llamada y Cuando.desdeLlamada cuentan desde que se armó',
      () async {
    await leer('ventas'); // antes de armar: no cuenta
    red.perderRespuesta(cuando: Cuando.llamada(2));
    red.cortar(cuando: Cuando.desdeLlamada(4));
    expect((await leer('a')).statusCode, 200); // 1
    await expectLater(leer('b'), errorDeRed); // 2: respuesta perdida
    expect((await leer('c')).statusCode, 200); // 3
    await expectLater(leer('d'), errorDeRed); // 4: sin conexión
    await expectLater(leer('e'), errorDeRed); // 5: sin conexión
    expect(red.perdidas, ['b']);
    expect(red.cortadas, ['d', 'e']);
    expect(recibidos.map((p) => p.url.pathSegments.last),
        ['ventas', 'a', 'b', 'c']);
  });

  test('fijarParametro reemplaza solo ese parámetro de esa RPC', () async {
    red.fijarParametro('crear_venta_apliques', 'p_fecha', '2001-01-02T12:00');
    await rpc('crear_venta_apliques', {'p_fecha': 'hoy', 'p_total': 24});
    await rpc('incrementar_venta', {'p_fecha': 'hoy'});
    expect(jsonDecode(recibidos[0].body),
        {'p_fecha': '2001-01-02T12:00', 'p_total': 24});
    expect(
        recibidos[0].headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(recibidos[1].body), {'p_fecha': 'hoy'});
  });
}
