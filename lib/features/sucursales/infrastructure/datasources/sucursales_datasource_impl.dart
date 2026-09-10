import 'package:textiles_app/config/supabase/supabase_config.dart';
import '../../domain/domain.dart';
import '../infrastructure.dart';

class SucursalesDatasourceImpl implements SucursalesDatasource {
  final _db = SupabaseConfig.client;
  static const _table = 'sucursales';

  final int idusuario; // se mantiene por compatibilidad de firma
  SucursalesDatasourceImpl({this.idusuario = 1});

  @override
  Future<List<Sucursal>> getSucursales() async {
    final list = await _db.from(_table).select().eq('activo', true).order('id');
    return list.map<Sucursal>((e) => SucursalMapper.jsonToEntity(e)).toList();
  }

  @override
  Future<Sucursal> getSucursal(int id) async {
    if (id == 0) return Sucursal.empty();
    final row =
        await _db.from(_table).select().eq('id', id).maybeSingle();
    if (row == null) return Sucursal.empty();
    return SucursalMapper.jsonToEntity(row);
  }

  @override
  Future<Sucursal> createSucursal(Map<String, dynamic> sucursalLike) async {
    final data = Map<String, dynamic>.from(sucursalLike)..remove('id');
    final row = await _db.from(_table).insert(data).select().single();
    return SucursalMapper.jsonToEntity(row);
  }

  @override
  Future<Sucursal> updateSucursal(
      Map<String, dynamic> sucursalLike, int id) async {
    final data = Map<String, dynamic>.from(sucursalLike)..remove('id');
    final row =
        await _db.from(_table).update(data).eq('id', id).select().single();
    return SucursalMapper.jsonToEntity(row);
  }

  // Baja lógica: nunca se borra físicamente, solo activo = false.
  @override
  Future<bool> deleteSucursal(int id) async {
    final rows = await _db
        .from(_table)
        .update({'activo': false})
        .eq('id', id)
        .select('id');
    return rows.isNotEmpty;
  }

  @override
  Future<List<TelaSucursal>> getTelasSucursal(int idsucursal) async {
    final list = await _db
        .from('telas')
        .select('id, nombre, tela_sucursales(activo)')
        .eq('tela_sucursales.idsucursal', idsucursal)
        .order('nombre');
    return list
        .map<TelaSucursal>((e) => TelaSucursalMapper.jsonToEntity(e))
        .toList();
  }

  @override
  Future<void> setTelaSucursal(int idtela, int idsucursal, bool activo) async {
    await _db.from('tela_sucursales').upsert({
      'idtela': idtela,
      'idsucursal': idsucursal,
      'activo': activo,
    });
  }
}
