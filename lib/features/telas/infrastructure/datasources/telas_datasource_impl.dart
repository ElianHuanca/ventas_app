import 'package:textiles_app/config/supabase/supabase_config.dart';
import '../../domain/domain.dart';
import '../infrastructure.dart';

class TelasDatasourceImpl implements TelasDatasource {
  final _db = SupabaseConfig.client;
  static const _table = 'telas';

  @override
  Future<List<Tela>> getTelas() async {
    final list = await _db.from(_table).select();
    final telas = list.map<Tela>((e) => TelaMapper.jsonToEntity(e)).toList();
    // ordenado por nombre ascendente, sin distinguir mayúsculas (equiv. COLLATE NOCASE)
    telas.sort((a, b) =>
        a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return telas;
  }

  @override
  Future<Tela> getTela(int id) async {
    if (id == 0) return Tela.empty();
    final row = await _db.from(_table).select().eq('id', id).maybeSingle();
    if (row == null) return Tela.empty();
    return TelaMapper.jsonToEntity(row);
  }

  @override
  Future<Tela> createTela(Map<String, dynamic> telaLike) async {
    final data = Map<String, dynamic>.from(telaLike)..remove('id');
    final row = await _db.from(_table).insert(data).select().single();
    return TelaMapper.jsonToEntity(row);
  }

  @override
  Future<Tela> updateTela(Map<String, dynamic> telaLike, int id) async {
    final data = Map<String, dynamic>.from(telaLike)..remove('id');
    final row =
        await _db.from(_table).update(data).eq('id', id).select().single();
    return TelaMapper.jsonToEntity(row);
  }

  @override
  Future<bool> deleteTela(int id) async {
    final rows = await _db.from(_table).delete().eq('id', id).select('id');
    return rows.isNotEmpty;
  }
}
