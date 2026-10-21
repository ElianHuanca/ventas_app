import 'package:textiles_app/config/supabase/supabase_config.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';

class DashboardDatasourceImpl extends DashboardDatasource {
  final _db = SupabaseConfig.client;

  @override
  Future<List<TopProducto>> getTopProductos({
    required DateTime desde,
    required DateTime hasta,
  }) =>
      _top('top_productos', desde: desde, hasta: hasta);

  @override
  Future<List<TopProducto>> getTopApliques({
    required DateTime desde,
    required DateTime hasta,
  }) =>
      _top('top_apliques', desde: desde, hasta: hasta);

  /// `top_productos` (telas) y `top_apliques` devuelven las mismas columnas.
  Future<List<TopProducto>> _top(String rpc,
      {required DateTime desde, required DateTime hasta}) async {
    final hastaFin = _finDelDia(hasta);

    final rows = await _db.rpc<List<dynamic>>(rpc, params: {
      'desde': desde.toIso8601String(),
      'hasta': hastaFin.toIso8601String(),
    });

    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => TopProducto(
              nombre: row['nombre'] as String? ?? 'Sin nombre',
              totalVendido: (row['total_vendido'] as num?)?.toDouble() ?? 0.0,
              totalCantidad: (row['total_cantidad'] as num?)?.toDouble() ?? 0.0,
            ))
        .toList();
  }

  @override
  Future<ResumenVentas> getResumenVentas({
    required DateTime desde,
    required DateTime hasta,
  }) =>
      _resumen('resumen_ventas', desde: desde, hasta: hasta);

  @override
  Future<ResumenVentas> getResumenVentasApliques({
    required DateTime desde,
    required DateTime hasta,
  }) =>
      _resumen('resumen_ventas_apliques', desde: desde, hasta: hasta);

  Future<ResumenVentas> _resumen(String rpc,
      {required DateTime desde, required DateTime hasta}) async {
    final hastaFin = _finDelDia(hasta);

    final result = await _db.rpc<dynamic>(rpc, params: {
      'desde': desde.toIso8601String(),
      'hasta': hastaFin.toIso8601String(),
    });

    // La función devuelve una sola fila (puede llegar como lista o como mapa).
    final row = (result is List ? result.first : result) as Map<String, dynamic>;
    return ResumenVentas(
      total: (row['total'] as num?)?.toDouble() ?? 0.0,
      ganancias: (row['ganancias'] as num?)?.toDouble() ?? 0.0,
      descuento: (row['descuento'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Último instante del día. `fecha` se guarda con fracción de segundo
  /// ("…T23:59:59.500"), y las RPC comparan como texto: con 23:59:59 a secas
  /// una venta en el último segundo del día quedaba fuera del rango.
  static DateTime _finDelDia(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999, 999);
}
