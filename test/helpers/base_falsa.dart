/// Supabase de mentira para probar en `test/` los `*DatasourceImpl` reales
/// (y lo que hay arriba: repositorios, blocs, pantallas) sin red ni base.
///
/// Los datasources leen `SupabaseConfig.client` (= `Supabase.instance.client`)
/// al crearse. [usarBaseFalsa] inicializa ese cliente, como `red/celular.dart`,
/// con una [BaseFalsa] como `httpClient`: los pedidos que arma el cliente de
/// Supabase de verdad (PostgREST y Auth) llegan acá y se responden desde
/// tablas en memoria. No se toca `lib/`.
///
/// La [BaseFalsa] entiende solo lo que usan estos tests:
/// - `GET /rest/v1/<tabla>`: `select` con columnas, `*` y un embed
///   (`otra(*)` / `otra!inner(*)`, uno a muchos por [BaseFalsa.relacion]),
///   filtros `col=eq.v` y `otra.col=eq.v`, `order` y `limit`.
/// - `POST /rest/v1/<tabla>`: alta con defaults, id serial y restricciones
///   UNIQUE ([BaseFalsa.tabla] `unicos:`), que miran TODAS las filas (también
///   las dadas de baja), como Postgres. Si choca responde 409 con el mismo
///   JSON que PostgREST (`code` 23505).
/// - [BaseFalsa.sinConexion]: todo pedido falla antes de salir, con la
///   `ClientException` que tira `IOClient` cuando no hay red.
///
/// Lo que no entiende responde 501 (el test falla con el pedido a la vista).
/// No reemplaza a la integración ni a pgTAP: la base de verdad, sus RLS y
/// sus restricciones se prueban contra el Supabase local.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// http llega con supabase_flutter (es el tipo del `httpClient` de
// `Supabase.initialize`); no se agrega al pubspec solo para los tests.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Inicializa `Supabase.instance` con una [BaseFalsa] para todo el archivo
/// (`setUpAll`; se libera en `tearDownAll`) y la vacía antes de cada test.
/// Llamarla al principio de `main()`. Los datasources se crean dentro de cada
/// test (después de inicializar), igual que en la app.
BaseFalsa usarBaseFalsa() {
  final base = BaseFalsa();
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'http://base-falsa.test',
      publishableKey: 'sb_publishable_de_prueba',
      httpClient: base,
      debug: false,
      // Sin shared_preferences ni deep links (no hay plugins en el test) y
      // sin el timer de refresco de la sesión.
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _PkceEnMemoria(),
        detectSessionInUri: false,
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(base.reiniciar);
  return base;
}

typedef Fila = Map<String, Object?>;

class BaseFalsa extends http.BaseClient {
  final _tablas = <String, List<Fila>>{};
  final _defaults = <String, Fila>{};
  final _unicos = <String, List<(String, List<String>)>>{};

  /// (tabla, embebida) → (columna de la tabla, columna de la embebida).
  final _relaciones = <(String, String), (String, String)>{};

  /// Si es `true`, ningún pedido sale (sin red).
  bool sinConexion = false;

  /// Pedidos recibidos, en orden (también los que fallaron sin conexión).
  final pedidos = <http.BaseRequest>[];

  void reiniciar() {
    _tablas.clear();
    _defaults.clear();
    _unicos.clear();
    _relaciones.clear();
    sinConexion = false;
    pedidos.clear();
  }

  /// Crea (o reemplaza) [nombre] con [filas]. [defaults] completa las
  /// columnas que un alta no manda; [unicos] son las restricciones UNIQUE:
  /// `(nombre de la restricción, columnas)`.
  void tabla(
    String nombre,
    List<Fila> filas, {
    Fila defaults = const {},
    List<(String, List<String>)> unicos = const [],
  }) {
    _tablas[nombre] = [for (final f in filas) Map.of(f)];
    _defaults[nombre] = defaults;
    _unicos[nombre] = unicos;
  }

  /// Embed uno a muchos: cada fila de [tabla] lleva las de [embebida] con
  /// `embebida.referencia == tabla.columna` (la FK que usa PostgREST).
  void relacion(String tabla, String embebida,
      {required String columna, required String referencia}) {
    _relaciones[(tabla, embebida)] = (columna, referencia);
  }

  /// Filas actuales de [nombre] (para verificar qué quedó).
  List<Fila> filas(String nombre) => _tablas[nombre] ?? const [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    pedidos.add(request);
    if (sinConexion) {
      // Lo mismo que tira IOClient cuando no resuelve el host (sin red).
      throw http.ClientException(
          'Failed host lookup: ${request.url.host}', request.url);
    }
    final ruta = request.url.pathSegments;
    if (ruta.length == 3 && ruta[0] == 'rest' && ruta[1] == 'v1') {
      final tabla = ruta[2];
      if (!_tablas.containsKey(tabla)) {
        return _responder(request, 404, {
          'code': '42P01',
          'message': 'relation "public.$tabla" does not exist',
        });
      }
      final cuerpo = request is http.Request ? request.body : '';
      try {
        switch (request.method) {
          case 'GET':
            return _consultar(request, tabla);
          case 'POST':
            return _insertar(request, tabla, cuerpo);
        }
      } on _NoSimulado catch (e) {
        return _responder(request, 501, {'message': e.mensaje});
      }
    }
    return _responder(request, 501, {
      'message': 'BaseFalsa no simula ${request.method} ${request.url}',
    });
  }

  http.StreamedResponse _consultar(http.BaseRequest request, String tabla) {
    final q = request.url.queryParameters;
    final seleccion = _Seleccion.parsear(q['select'] ?? '*');
    final propios = <String, String>{};
    final deEmbed = <String, Map<String, String>>{};
    for (final MapEntry(:key, :value) in q.entries) {
      if (const {'select', 'order', 'limit', 'offset'}.contains(key)) continue;
      if (!value.startsWith('eq.')) {
        throw _NoSimulado('filtro no simulado: $key=$value');
      }
      final valor = value.substring(3);
      final punto = key.indexOf('.');
      if (punto < 0) {
        propios[key] = valor;
      } else {
        (deEmbed[key.substring(0, punto)] ??= {})[key.substring(punto + 1)] =
            valor;
      }
    }

    var filas = [
      for (final f in _tablas[tabla]!)
        if (_cumple(f, propios)) Map.of(f),
    ];
    for (final embed in seleccion.embeds) {
      final rel = _relaciones[(tabla, embed.tabla)];
      if (rel == null) {
        throw _NoSimulado('sin relación $tabla → ${embed.tabla}');
      }
      final (columna, referencia) = rel;
      final filtros = deEmbed[embed.tabla] ?? const {};
      filas = [
        for (final f in filas)
          if (_embeber(f, embed, columna, referencia, filtros) case final c?) c,
      ];
    }
    if (q['order'] case final orden?) {
      // `col.asc|desc[.nullsfirst|.nullslast]`; postgrest-dart manda `desc`
      // si no se pide `ascending: true`.
      final partes = orden.split('.');
      final columna = partes.first;
      final desc = partes.length > 1 && partes[1] == 'desc';
      filas.sort((a, b) {
        final (x, y) = (a[columna], b[columna]);
        final c = x is num && y is num ? x.compareTo(y) : '$x'.compareTo('$y');
        return desc ? -c : c;
      });
    }
    if (q['limit'] case final limite?) {
      filas = filas.take(int.parse(limite)).toList();
    }
    final resultado = [for (final f in filas) seleccion.proyectar(f)];
    return _responderFilas(request, resultado);
  }

  /// La fila con su embed, o null si es `!inner` y no le queda ninguna.
  Fila? _embeber(Fila fila, _Embed embed, String columna, String referencia,
      Map<String, String> filtros) {
    final hijas = [
      for (final h in _tablas[embed.tabla] ?? const <Fila>[])
        if ('${h[referencia]}' == '${fila[columna]}' && _cumple(h, filtros))
          embed.seleccion.proyectar(h),
    ];
    if (embed.inner && hijas.isEmpty) return null;
    return fila..[embed.tabla] = hijas;
  }

  http.StreamedResponse _insertar(
      http.BaseRequest request, String tabla, String cuerpo) {
    final json = jsonDecode(cuerpo);
    final nuevas = [
      for (final f in json is List ? json : [json]) Map<String, Object?>.of(f as Fila),
    ];
    final filas = _tablas[tabla]!;
    final insertadas = <Fila>[];
    for (final nueva in nuevas) {
      final fila = {..._defaults[tabla]!, ...nueva};
      fila['id'] ??= filas.fold<int>(
              0, (m, f) => (f['id'] as int? ?? 0) > m ? f['id']! as int : m) +
          1;
      for (final (restriccion, columnas) in _unicos[tabla]!) {
        final choca = filas.any((f) => columnas.every((c) => f[c] == fila[c]));
        if (choca) {
          final cols = columnas.join(', ');
          final vals = columnas.map((c) => fila[c]).join(', ');
          return _responder(request, 409, {
            'code': '23505',
            'details': 'Key ($cols)=($vals) already exists.',
            'hint': null,
            'message':
                'duplicate key value violates unique constraint "$restriccion"',
          });
        }
      }
      filas.add(fila);
      insertadas.add(fila);
    }
    final prefer = request.headers['Prefer'] ?? '';
    if (!prefer.contains('return=representation')) {
      return _responder(request, 201, null);
    }
    final seleccion =
        _Seleccion.parsear(request.url.queryParameters['select'] ?? '*');
    return _responderFilas(
        request, [for (final f in insertadas) seleccion.proyectar(f)],
        estado: 201);
  }

  static bool _cumple(Fila fila, Map<String, String> filtros) =>
      filtros.entries.every((e) => '${fila[e.key]}' == e.value);

  /// Un arreglo, o un objeto si se pidió uno solo (`.single()`).
  http.StreamedResponse _responderFilas(
      http.BaseRequest request, List<Fila> filas,
      {int estado = 200}) {
    final accept = request.headers['Accept'] ?? '';
    if (!accept.contains('application/vnd.pgrst.object+json')) {
      return _responder(request, estado, filas);
    }
    if (filas.length != 1) {
      return _responder(request, 406, {
        'code': 'PGRST116',
        'details': 'The result contains ${filas.length} rows',
        'hint': null,
        'message': 'JSON object requested, multiple (or no) rows returned',
      });
    }
    return _responder(request, estado, filas.single);
  }

  static http.StreamedResponse _responder(
      http.BaseRequest request, int estado, Object? cuerpo) {
    final bytes = cuerpo == null ? <int>[] : utf8.encode(jsonEncode(cuerpo));
    return http.StreamedResponse(
      Stream.value(bytes),
      estado,
      request: request,
      contentLength: bytes.length,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// El `select` de PostgREST: columnas, `*` y embeds `tabla(...)` /
/// `tabla!inner(...)`.
class _Seleccion {
  _Seleccion(this.columnas, this.embeds);

  final List<String> columnas;
  final List<_Embed> embeds;

  static _Seleccion parsear(String texto) {
    final columnas = <String>[];
    final embeds = <_Embed>[];
    for (final parte in _partir(texto.replaceAll(' ', ''))) {
      final abre = parte.indexOf('(');
      if (abre < 0) {
        columnas.add(parte);
        continue;
      }
      final nombre = parte.substring(0, abre);
      final interior = parte.substring(abre + 1, parte.length - 1);
      final [tabla, ...modificadores] = nombre.split('!');
      embeds.add(_Embed(
          tabla, modificadores.contains('inner'), parsear(interior)));
    }
    return _Seleccion(columnas, embeds);
  }

  /// Parte por las comas de primer nivel (no las de adentro de un embed).
  static List<String> _partir(String texto) {
    final partes = <String>[];
    var nivel = 0;
    var desde = 0;
    for (var i = 0; i < texto.length; i++) {
      switch (texto[i]) {
        case '(':
          nivel++;
        case ')':
          nivel--;
        case ',' when nivel == 0:
          partes.add(texto.substring(desde, i));
          desde = i + 1;
      }
    }
    partes.add(texto.substring(desde));
    return partes.where((p) => p.isNotEmpty).toList();
  }

  Fila proyectar(Fila fila) => {
        for (final MapEntry(:key, :value) in fila.entries)
          if (columnas.contains('*') ||
              columnas.contains(key) ||
              embeds.any((e) => e.tabla == key))
            key: value,
      };
}

class _Embed {
  _Embed(this.tabla, this.inner, this.seleccion);

  final String tabla;
  final bool inner;
  final _Seleccion seleccion;
}

/// Un pedido que la [BaseFalsa] no sabe responder (sale como 501).
class _NoSimulado implements Exception {
  _NoSimulado(this.mensaje);

  final String mensaje;
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
