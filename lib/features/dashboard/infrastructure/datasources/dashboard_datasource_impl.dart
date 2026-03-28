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
      SELECT dv.nombre, SUM(dv.total) AS total_vendido
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
            ))
        .toList();
  }
}
