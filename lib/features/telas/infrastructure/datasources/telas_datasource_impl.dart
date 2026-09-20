import 'package:textiles_app/config/supabase/supabase_config.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import '../../domain/domain.dart';
import '../infrastructure.dart';

class TelasDatasourceImpl implements TelasDatasource {
  final _db = SupabaseConfig.client;
  static const _table = 'telas';

  @override
  Future<List<Tela>> getTelas({bool soloActivos = true}) async {
    var query = _db.from(_table).select();
    if (soloActivos) query = query.eq('activo', true);
    final list = await query;
    final telas = list.map<Tela>((e) => TelaMapper.jsonToEntity(e)).toList();
    // ordenado por nombre ascendente, sin distinguir mayúsculas (equiv. COLLATE NOCASE)
    telas.sort((a, b) =>
        a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return telas;
  }

  @override
  Future<List<Tela>> getTelasPorSucursal(int idsucursal) async {
    // Regla de transición: si la sucursal no tiene NINGUNA vinculación
    // configurada en tela_sucursales, se muestra todo el catálogo.
    final vinculos = await _db
        .from('tela_sucursales')
        .select('idtela')
        .eq('idsucursal', idsucursal)
        .eq('activo', true)
        .limit(1);
    if (vinculos.isEmpty) return getTelas();

    final list = await _db
        .from(_table)
        .select('*, tela_sucursales!inner(*)')
        .eq('activo', true)
        .eq('tela_sucursales.idsucursal', idsucursal)
        .eq('tela_sucursales.activo', true);
    final telas = list.map<Tela>((e) => TelaMapper.jsonToEntity(e)).toList();
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
  Future<List<ColorItem>> getColoresTela(int idtela) async {
    final list = await _db
        .from('colores')
        .select('id, nombre, hex, tela_colores(activo)')
        .eq('activo', true)
        .eq('tela_colores.idtela', idtela)
        .order('nombre');
    return list
        .map<ColorItem>((e) => ColorItem(
              id: e['id'] as int,
              nombre: e['nombre'] ?? '',
              hex: e['hex'] ?? '',
              vinculado: e['tela_colores'] is List &&
                  (e['tela_colores'] as List)
                      .any((v) => v is Map && (v['activo'] ?? false)),
            ))
        .toList();
  }

  @override
  Future<void> setColorTela(int idtela, int idcolor, bool activo) async {
    await _db.from('tela_colores').upsert({
      'idtela': idtela,
      'idcolor': idcolor,
      'activo': activo,
    });
  }
}
