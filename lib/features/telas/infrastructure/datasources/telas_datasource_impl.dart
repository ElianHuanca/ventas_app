import 'package:textiles_app/features/database/database_helper.dart';
import '../../domain/domain.dart';
import '../infrastructure.dart';

class TelasDatasourceImpl implements TelasDatasource {
  final DatabaseHelper _db = DatabaseHelper();
  final int idusuario;

  TelasDatasourceImpl({this.idusuario = 1});

  Map<String, dynamic> _rowToMap(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'nombre': row['nombre'] ?? '',
      'precxmen': (row['precxmen'] as num?)?.toDouble() ?? 0.0,
      'precxmay': (row['precxmay'] as num?)?.toDouble() ?? 0.0,
      'precxrollo': (row['precxrollo'] as num?)?.toDouble() ?? 0.0,
      'precxcompra': (row['precxcompra'] as num?)?.toDouble() ?? 0.0,
      'idusuarios': row['idusuarios'] ?? idusuario,
    };
  }

  @override
  Future<List<Tela>> getTelas() async {
    final database = await _db.database;
    final list = await database.query('telas');
    return list
        .map<Tela>((e) => TelaMapper.jsonToEntity(_rowToMap(e)))
        .toList();
  }

  @override
  Future<Tela> getTela(int id) async {
    if (id == 0) return Tela.empty();
    final database = await _db.database;
    final list = await database.query('telas', where: 'id = ?', whereArgs: [id]);
    if (list.isEmpty) return Tela.empty();
    return TelaMapper.jsonToEntity(_rowToMap(list.first));
  }

  @override
  Future<Tela> createTela(Map<String, dynamic> telaLike) async {
    final database = await _db.database;
    telaLike = Map.from(telaLike)..remove('id');
    telaLike['idusuarios'] = idusuario;
    final id = await database.insert('telas', telaLike);
    return getTela(id);
  }

  @override
  Future<Tela> updateTela(Map<String, dynamic> telaLike, int id) async {
    final database = await _db.database;
    telaLike = Map.from(telaLike)..remove('id');
    await database.update('telas', telaLike, where: 'id = ?', whereArgs: [id]);
    return getTela(id);
  }

  @override
  Future<bool> deleteTela(int id) async {
    final database = await _db.database;
    final n = await database.delete('telas', where: 'id = ?', whereArgs: [id]);
    return n > 0;
  }
}
