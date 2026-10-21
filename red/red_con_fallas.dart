/// Un `http.Client` que simula la red del celular cuando se corta: lo usa el
/// cliente de Supabase de la app (`SupabaseConfig.client`) en los tests de
/// `red/` para ver qué deja en la base una respuesta que no llega.
///
/// - **Respuesta perdida**: el pedido llega a la base, se espera su respuesta
///   completa (la transacción ya hizo commit) y en vez de devolverla se lanza
///   el mismo error que tira `IOClient` cuando se corta la conexión mientras
///   recibe (`ClientException: Connection closed while receiving data`).
///   Para la app es un error; para la base, la operación ya se aplicó.
/// - **Sin conexión**: falla antes de mandar nada (`ClientException` de un
///   socket que no conecta). La base no se entera.
///
/// Cada falla alcanza a los pedidos que cumplen su [Cuando] (todos, una RPC
/// por nombre, una tabla, la llamada N desde que se armó…) y se gasta después
/// de `veces` pedidos (sin `veces`, dura hasta [RedConFallas.restablecer]).
library;

import 'dart:convert';

// http llega con supabase_flutter (es el tipo del `httpClient` de
// `Supabase.initialize`); no se agrega al pubspec solo para estos tests.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

/// Qué le pasa a un pedido.
enum Desenlace {
  /// Llegó a la base y la respuesta volvió a la app.
  entregado,

  /// Llegó a la base, pero la respuesta no volvió (la app ve un error).
  respuestaPerdida,

  /// No salió del celular (la base no se enteró).
  sinConexion,
}

/// Un pedido que pasó por la red, para que los tests verifiquen que la falla
/// cayó donde querían.
class PedidoVisto {
  PedidoVisto(this.metodo, this.url, this.desenlace, [this.status]);

  final String metodo;
  final Uri url;
  final Desenlace desenlace;

  /// Código HTTP que devolvió la base (null si no llegó).
  final int? status;

  /// Ruta de PostgREST sin `/rest/v1/`: `rpc/crear_venta_apliques`,
  /// `detalle_ventas`… (para auth y el resto, la ruta completa).
  String get ruta => rutaDe(url);

  @override
  String toString() => '$metodo $ruta → ${desenlace.name}'
      '${status == null ? '' : ' ($status)'}';
}

String rutaDe(Uri url) {
  const rest = '/rest/v1/';
  return url.path.startsWith(rest) ? url.path.substring(rest.length) : url.path;
}

/// A qué pedidos alcanza una falla. `n` es el número de pedido (desde 1)
/// contado desde que se armó la falla, sea cual sea.
class Cuando {
  const Cuando._(this._coincide, this._descripcion);

  final bool Function(http.BaseRequest pedido, int n) _coincide;
  final String _descripcion;

  bool coincide(http.BaseRequest pedido, int n) => _coincide(pedido, n);

  /// Cualquier pedido.
  static final siempre = Cuando._((_, __) => true, 'siempre');

  /// Solo la RPC [nombre] (`POST /rest/v1/rpc/<nombre>`).
  factory Cuando.rpc(String nombre) =>
      Cuando._((p, _) => rutaDe(p.url) == 'rpc/$nombre', 'rpc $nombre');

  /// Solo los pedidos a la tabla [tabla] (y con [metodo], si se da).
  factory Cuando.tabla(String tabla, {String? metodo}) => Cuando._(
      (p, _) =>
          rutaDe(p.url) == tabla &&
          (metodo == null || p.method == metodo.toUpperCase()),
      'tabla $tabla${metodo == null ? '' : ' ($metodo)'}');

  /// Solo la llamada [n] desde que se armó la falla.
  factory Cuando.llamada(int n) => Cuando._((_, i) => i == n, 'llamada $n');

  /// De la llamada [n] en adelante (p. ej. "se cortó la señal después de la
  /// primera respuesta").
  factory Cuando.desdeLlamada(int n) =>
      Cuando._((_, i) => i >= n, 'desde la llamada $n');

  @override
  String toString() => _descripcion;
}

class _Falla {
  _Falla(this.tipo, this.cuando, this.veces);

  final Desenlace tipo;
  final Cuando cuando;

  /// Pedidos que todavía hace fallar (null: hasta que se restablezca).
  int? veces;

  /// Pedidos vistos desde que se armó (cuenten o no).
  int vistos = 0;

  bool get gastada => veces != null && veces! <= 0;
}

class RedConFallas extends http.BaseClient {
  RedConFallas({http.Client? interno}) : _interno = interno ?? http.Client();

  final http.Client _interno;
  final _fallas = <_Falla>[];
  final _parametrosFijos = <String, Map<String, Object?>>{};

  /// Todos los pedidos que pasaron, en orden.
  final registro = <PedidoVisto>[];

  /// La próxima respuesta de un pedido que cumpla [cuando] (o las próximas
  /// [veces]) se pierde después de que la base la procesó.
  void perderRespuesta({Cuando? cuando, int? veces = 1}) => _fallas
      .add(_Falla(Desenlace.respuestaPerdida, cuando ?? Cuando.siempre, veces));

  /// Los pedidos que cumplan [cuando] no salen del celular. Sin [veces], la
  /// red sigue cortada para ellos hasta [restablecer].
  void cortar({Cuando? cuando, int? veces}) => _fallas
      .add(_Falla(Desenlace.sinConexion, cuando ?? Cuando.siempre, veces));

  /// Saca todas las fallas armadas (las que no se gastaron todavía).
  void restablecer() => _fallas.clear();

  /// Reemplaza el parámetro [parametro] de la RPC [rpc] por [valor] antes de
  /// mandarla. Sirve para fijar la fecha de las RPC cuyo datasource manda
  /// `DateTime.now()` (`crear_venta_apliques`): el resto del cuerpo queda
  /// como lo armó la app.
  void fijarParametro(String rpc, String parametro, Object? valor) =>
      (_parametrosFijos['rpc/$rpc'] ??= {})[parametro] = valor;

  /// Rutas de los pedidos que terminaron con [desenlace].
  List<String> con(Desenlace desenlace) => [
        for (final p in registro)
          if (p.desenlace == desenlace) p.ruta,
      ];

  List<String> get perdidas => con(Desenlace.respuestaPerdida);
  List<String> get cortadas => con(Desenlace.sinConexion);
  List<String> get entregadas => con(Desenlace.entregado);

  /// Rutas de los pedidos que llegaron a la base (entregados o con la
  /// respuesta perdida).
  List<String> get llegaron => [
        for (final p in registro)
          if (p.desenlace != Desenlace.sinConexion) p.ruta,
      ];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final pedido = _conParametrosFijos(request);
    final falla = _fallaPara(pedido);

    if (falla == Desenlace.sinConexion) {
      registro.add(PedidoVisto(pedido.method, pedido.url, falla!));
      throw http.ClientException(
          'SocketException: Network is unreachable (sin conexión simulada)',
          pedido.url);
    }

    final respuesta = await _interno.send(pedido);
    if (falla == Desenlace.respuestaPerdida) {
      // Se lee la respuesta entera: recién ahí es seguro que la base terminó
      // (PostgREST responde después del commit).
      await respuesta.stream.drain<void>();
      registro.add(
          PedidoVisto(pedido.method, pedido.url, falla!, respuesta.statusCode));
      throw http.ClientException(
          'Connection closed while receiving data (respuesta perdida '
          'simulada)',
          pedido.url);
    }
    registro.add(PedidoVisto(
        pedido.method, pedido.url, Desenlace.entregado, respuesta.statusCode));
    return respuesta;
  }

  /// Cuenta el pedido en todas las fallas armadas y devuelve la primera que
  /// lo alcanza (gastándole una vez).
  Desenlace? _fallaPara(http.BaseRequest pedido) {
    Desenlace? elegida;
    for (final falla in _fallas) {
      falla.vistos++;
      if (elegida != null || falla.gastada) continue;
      if (!falla.cuando.coincide(pedido, falla.vistos)) continue;
      elegida = falla.tipo;
      if (falla.veces != null) falla.veces = falla.veces! - 1;
    }
    _fallas.removeWhere((f) => f.gastada);
    return elegida;
  }

  http.BaseRequest _conParametrosFijos(http.BaseRequest request) {
    final fijos = _parametrosFijos[rutaDe(request.url)];
    if (fijos == null || request is! http.Request) return request;
    final cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
    final copia = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..followRedirects = request.followRedirects
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection
      ..body = jsonEncode({...cuerpo, ...fijos});
    return copia;
  }

  @override
  void close() {
    _interno.close();
    super.close();
  }
}
