import 'package:textiles_app/config/supabase/supabase_config.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';

class DashboardDatasourceImpl extends DashboardDatasource {
  final _db = SupabaseConfig.client;

  @override
  Future<List<TopProducto>> getTopProductos({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final hastaFin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);

    final rows = await _db.rpc('top_productos', params: {
      'desde': desde.toIso8601String(),
      'hasta': hastaFin.toIso8601String(),
    }) as List;

    return rows
        .map((row) => TopProducto(
              nombre: row['nombre'] as String? ?? 'Sin nombre',
              totalVendido: (row['total_vendido'] as num?)?.toDouble() ?? 0.0,
              totalCantidad: (row['total_cantidad'] as num?)?.toInt() ?? 0,
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
    final hastaFin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);

    final result = await _db.rpc(rpc, params: {
      'desde': desde.toIso8601String(),
      'hasta': hastaFin.toIso8601String(),
    });

    // La función devuelve una sola fila (puede llegar como lista o como mapa).
    final row = result is List ? result.first : result;
    return ResumenVentas(
      total: (row['total'] as num?)?.toDouble() ?? 0.0,
      ganancias: (row['ganancias'] as num?)?.toDouble() ?? 0.0,
      descuento: (row['descuento'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
