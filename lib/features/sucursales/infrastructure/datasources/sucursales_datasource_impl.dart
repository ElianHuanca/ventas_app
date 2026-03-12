import 'package:textiles_app/features/database/database_helper.dart';
import '../../domain/domain.dart';
import '../infrastructure.dart';

class SucursalesDatasourceImpl implements SucursalesDatasource {
  final DatabaseHelper _db = DatabaseHelper();
  final int idusuario; // ignorado en SQLite, se mantiene por compatibilidad

  SucursalesDatasourceImpl({this.idusuario = 1});

  @override
  Future<List<Sucursal>> getSucursales() async {
    final database = await _db.database;
    final list = await database.query('sucursales');
    return list
        .map<Sucursal>((e) => SucursalMapper.jsonToEntity(e))
        .toList();
  }

  @override
  Future<Sucursal> getSucursal(int id) async {
    if (id == 0) return Sucursal.empty();
    final database = await _db.database;
    final list =
        await database.query('sucursales', where: 'id = ?', whereArgs: [id]);
    if (list.isEmpty) return Sucursal.empty();
    return SucursalMapper.jsonToEntity(list.first);
  }

  @override
  Future<Sucursal> createSucursal(Map<String, dynamic> sucursalLike) async {
    final database = await _db.database;
    sucursalLike.remove('id');
    final id = await database.insert('sucursales', sucursalLike);
    return getSucursal(id);
  }

  @override
  Future<Sucursal> updateSucursal(
      Map<String, dynamic> sucursalLike, int id) async {
    final database = await _db.database;
    sucursalLike.remove('id');
    await database.update(
      'sucursales',
      sucursalLike,
      where: 'id = ?',
      whereArgs: [id],
    );
    return getSucursal(id);
  }

  @override
  Future<bool> deleteSucursal(int id) async {
    final database = await _db.database;
    final n = await database.delete(
      'sucursales',
      where: 'id = ?',
      whereArgs: [id],
    );
    return n > 0;
  }
}
