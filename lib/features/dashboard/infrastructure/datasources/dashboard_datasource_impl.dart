import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/database/database_helper.dart';

class DashboardDatasourceImpl extends DashboardDatasource {
  final DatabaseHelper _db = DatabaseHelper();

  @override
  Future<List<TopProducto>> getTopProductos({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final database = await _db.database;

    // hasta al final del día
    final hastaFin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);

    final rows = await database.rawQuery('''
      SELECT dv.nombre,
             SUM(dv.total) AS total_vendido,
             SUM(dv.cantidad) AS total_cantidad
      FROM detalle_ventas dv
      JOIN ventas v ON dv.idventa = v.id
      WHERE v.fecha >= ? AND v.fecha <= ?
      GROUP BY dv.nombre
      ORDER BY total_vendido DESC
    ''', [desde.toIso8601String(), hastaFin.toIso8601String()]);

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
  }) async {
    final database = await _db.database;
    final hastaFin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);

    final rows = await database.rawQuery('''
      SELECT COALESCE(SUM(total), 0) AS total,
             COALESCE(SUM(ganancias), 0) AS ganancias,
             COALESCE(SUM(descuento), 0) AS descuento
      FROM ventas
      WHERE fecha >= ? AND fecha <= ?
    ''', [desde.toIso8601String(), hastaFin.toIso8601String()]);

    final row = rows.first;
    return ResumenVentas(
      total: (row['total'] as num).toDouble(),
      ganancias: (row['ganancias'] as num).toDouble(),
      descuento: (row['descuento'] as num).toDouble(),
    );
  }
}
