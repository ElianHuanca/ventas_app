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
  Future<Venta?> getVentaByFecha(int idsucursales, DateTime fecha) async {
    final database = await _db.database;
    final dateStr = fecha.toIso8601String().substring(0, 10);
    final list = await database.query('ventas',
        where: "idsucursales = ? AND fecha LIKE ?",
        whereArgs: [idsucursales, '$dateStr%']);
    if (list.isEmpty) return null;
    return VentaMapper.jsonToEntity(_rowToMap(list.first));
  }

  @override
  Future<Venta> createVentaAhora(int idsucursales) async {
    return createVenta(idsucursales, DateTime.now());
  }

  @override
  Future<Venta> createVenta(int idsucursales, DateTime fecha) async {
    final database = await _db.database;
    final id = await database.insert('ventas', {
      'fecha': fecha.toIso8601String(),
      'total': 0,
      'ganancias': 0,
      'descuento': 0,
      'idsucursales': idsucursales,
    });
    return getVenta(id);
  }

  @override
  Future<void> deleteVenta(int id) async {
    final database = await _db.database;
    await database.delete('ventas', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Venta> actualizarVenta(Map<String, dynamic> ventaLike, int id) async {
    final database = await _db.database;
    final delta = Map<String, dynamic>.from(ventaLike)..remove('id');
    final setClauses = delta.keys
        .map((k) => k == 'fecha' ? '$k = ?' : '$k = $k + ?')
        .join(', ');
    await database.rawUpdate(
      'UPDATE ventas SET $setClauses WHERE id = ?',
      [...delta.values, id],
    );
    return getVenta(id);
  }
}
