/// `Supabase.instance` con una red de mentira, para recorrer los vectores con
/// el código real de los datasources (que leen `SupabaseConfig.client`) sin
/// tocar ninguna base: cada pedido queda anotado en [RedDePrueba.pedidos] y la
/// respuesta la decide el test.
///
/// Los parámetros de las RPC (`registrar_venta_telas`, `crear_venta_apliques`,
/// `registrar_produccion`, `inventario_con_ventas`) se arman dentro de los
/// datasources de Flutter; Android los tiene en funciones puras. Así se
/// comparan los dos con el cuerpo que de verdad sale por la red.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// http llega con supabase_flutter (como en red/): es el tipo de `httpClient`
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Un pedido que hizo la app.
class Pedido {
  Pedido(this.metodo, this.url, this.cuerpo);

  final String metodo;
  final Uri url;
  final String cuerpo;

  /// Nombre de la RPC (`/rest/v1/rpc/<nombre>`), o null si no es una RPC.
  String? get rpc => url.pathSegments.length == 4 &&
          url.pathSegments[2] == 'rpc'
      ? url.pathSegments[3]
      : null;

  /// El cuerpo JSON (los parámetros, en una RPC).
  Object? get json => jsonDecode(cuerpo);
}

class RedDePrueba extends http.BaseClient {
  final pedidos = <Pedido>[];

  /// Lo que devuelve la "base" (se manda como JSON). Por defecto, null.
  Object? Function(Pedido pedido) responder = (_) => null;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final cuerpo = request is http.Request ? request.body : '';
    final pedido = Pedido(request.method, request.url, cuerpo);
    pedidos.add(pedido);
    final respuesta = utf8.encode(jsonEncode(responder(pedido)));
    return http.StreamedResponse(
      Stream.value(respuesta),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

/// Inicializa `Supabase.instance` con [RedDePrueba]. Una vez por archivo de
/// test (`setUpAll`): cada archivo corre en su propio isolate.
Future<RedDePrueba> abrirSupabaseDePrueba() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final red = RedDePrueba();
  await Supabase.initialize(
    url: 'http://supabase.de.prueba',
    publishableKey: 'clave-de-prueba',
    httpClient: red,
    debug: false,
    // Sin plugins (shared_preferences, deep links) ni timers de refresco
    authOptions: FlutterAuthClientOptions(
      autoRefreshToken: false,
      localStorage: const EmptyLocalStorage(),
      pkceAsyncStorage: _PkceEnMemoria(),
      detectSessionInUri: false,
    ),
  );
  return red;
}

class _PkceEnMemoria extends GotrueAsyncStorage {
  final _items = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _items[key] = value;
}
