import 'package:textiles_app/features/database/database_helper.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/infrastructure/infrastructure.dart';

class VentasDatasourceImpl extends VentasDatasource {
  final DatabaseHelper _db = DatabaseHelper();

  Map<String, dynamic> _rowToMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'fecha': row['fecha'] != null
          ? (row['fecha'] is String
              ? row['fecha']
              : (row['fecha'] as DateTime).toIso8601String())
          : DateTime.now().toIso8601String(),
      'total': (row['total'] as num?)?.toDouble() ?? 0.0,
      'ganancias': (row['ganancias'] as num?)?.toDouble() ?? 0.0,
      'descuento': (row['descuento'] as num?)?.toDouble() ?? 0.0,
      'idsucursales': row['idsucursales'] as int? ?? 0,
    };
  }

  @override
  Future<List<Venta>> getVentas(int idsucursal) async {
    final database = await _db.database;
    final list = await database.query('ventas',
        where: 'idsucursales = ?',
        whereArgs: [idsucursal],
        orderBy: 'fecha DESC');
    return list.map((e) => VentaMapper.jsonToEntity(_rowToMap(e))).toList();
  }

  @override
  Future<Venta> getVenta(int id) async {
    final database = await _db.database;
    final list =
        await database.query('ventas', where: 'id = ?', whereArgs: [id]);
    if (list.isEmpty) throw Exception('Venta no encontrada');
    return VentaMapper.jsonToEntity(_rowToMap(list.first));
  }

  @override
  Future<Venta> createVentaAhora(int idsucursales) async {
    final database = await _db.database;
    final now = DateTime.now().toIso8601String();
    final id = await database.insert('ventas', {
      'fecha': now,
      'total': 0,
      'ganancias': 0,
      'descuento': 0,
      'idsucursales': idsucursales,
    });
    return getVenta(id);
  }

  @override
  Future<Venta> actualizarVenta(Map<String, dynamic> ventaLike, int id) async {
    final database = await _db.database;
    ventaLike = Map.from(ventaLike)..remove('id');
    await database
        .update('ventas', ventaLike, where: 'id = ?', whereArgs: [id]);
    return getVenta(id);
  }
}
