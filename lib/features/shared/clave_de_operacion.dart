import 'dart:math';

/// Clave de idempotencia de un envío: el `p_id_operacion` de las RPC de
/// escritura (`crear_venta_apliques`, `registrar_produccion`,
/// `registrar_venta_telas`). La base la guarda en la misma transacción que
/// la escritura; si la respuesta se pierde después del commit y el usuario
/// vuelve a tocar Guardar, el reintento lleva la misma clave y la base
/// devuelve lo de la primera vez sin volver a aplicarlo.
///
/// La clave queda atada a lo que se manda: mientras el envío sea el mismo
/// (mismo carrito, descuento, día…) [para] devuelve la misma; si cambió, es
/// otro envío y lleva otra. Un carrito que vuelve a quedar igual (agregar y
/// quitar la misma línea) reusa la clave: es el mismo envío y, si el
/// primero ya había llegado, la base no lo duplica. Cuando el envío sale
/// bien se [descartar]: el próximo es otra venta aunque sea igual.
class ClaveDeOperacion {
  ClaveDeOperacion({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  String? _clave;
  Object? _envio;

  /// La clave para mandar [envio]: listas, mapas y valores simples (números,
  /// textos, bool, null), comparados por contenido. La misma que la vez
  /// anterior si [envio] no cambió y no se descartó.
  ///
  /// Se guarda [envio] tal cual (sin copiarlo) para compararlo en el
  /// reintento: los cubits arman listas y mapas nuevos en cada cambio y no
  /// tocan los que ya emitieron.
  String para(Object? envio) {
    final clave = _clave;
    if (clave != null && _iguales(envio, _envio)) return clave;
    _envio = envio;
    return _clave = uuidV4(_random);
  }

  /// El envío salió bien: el próximo lleva otra clave.
  void descartar() {
    _clave = null;
    _envio = null;
  }
}

bool _iguales(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_iguales(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entrada in a.entries) {
      if (!b.containsKey(entrada.key) ||
          !_iguales(entrada.value, b[entrada.key])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}

/// Un uuid versión 4 (RFC 9562): 122 bits al azar, en minúsculas con
/// guiones (`xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`, y = 8, 9, a o b), como lo
/// acepta el tipo `uuid` de Postgres.
String uuidV4([Random? random]) {
  final azar = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => azar.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
