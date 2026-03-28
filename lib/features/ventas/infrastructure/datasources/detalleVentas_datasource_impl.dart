// ignore_for_file: file_names
import 'package:textiles_app/features/database/database_helper.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/infrastructure/mappers/detalleVenta_mapper.dart';

class DetalleVentasDatasourceImpl extends DetalleVentasDatasource {
  final DatabaseHelper _db = DatabaseHelper();

  Map<String, dynamic> _rowToMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'nombre': row['nombre'],
      'precio': (row['precio'] as num?)?.toDouble() ?? 0.0,
      'cantidad': (row['cantidad'] as num?)?.toDouble() ?? 0.0,
      'total': (row['total'] as num?)?.toDouble(),
      'ganancias': (row['ganancias'] as num?)?.toDouble(),
      'idtelas': row['idtelas'] as int? ?? 0,
    };
  }

  @override
  Future<List<DetalleVenta>> getDetalleVenta(int idventas) async {
    final database = await _db.database;
    final list = await database.query('detalle_ventas',
        where: 'idventa = ?', whereArgs: [idventas]);
    return list.map((e) => DetalleVentaMapper.jsonToEntity(_rowToMap(e))).toList();
  }

  @override
  Future<List<DetalleVenta>> createDetalleVenta(
      List<Map<String, dynamic>> detalleVentasLike, int idventas) async {
    final database = await _db.database;
    final results = <DetalleVenta>[];
    for (final item in detalleVentasLike) {
      final id = await database.insert('detalle_ventas', {
        'nombre': item['nombre'],
        'precio': item['precio'],
        'cantidad': item['cantidad'],
        'total': item['total'],
        'ganancias': item['ganancias'],
        'idtelas': item['idtelas'],
        'idventa': idventas,
      });
      final row = (await database.query('detalle_ventas',
          where: 'id = ?', whereArgs: [id]))
          .first;
      results.add(DetalleVentaMapper.jsonToEntity(_rowToMap(row)));
    }
    return results;
  }

  @override
  Future<DetalleVenta> deleteDetalleVenta(int id) async {
    final database = await _db.database;
    final list =
        await database.query('detalle_ventas', where: 'id = ?', whereArgs: [id]);
    if (list.isEmpty) throw Exception('Detalle no encontrado');
    final deleted = DetalleVentaMapper.jsonToEntity(_rowToMap(list.first));
    await database.delete('detalle_ventas', where: 'id = ?', whereArgs: [id]);
    return deleted;
  }
}
