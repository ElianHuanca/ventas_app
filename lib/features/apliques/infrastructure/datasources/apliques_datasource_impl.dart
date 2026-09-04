import 'package:textiles_app/config/supabase/supabase_config.dart';
import '../../domain/domain.dart';
import '../infrastructure.dart';

class ApliquesDatasourceImpl implements ApliquesDatasource {
  final _db = SupabaseConfig.client;
  static const _table = 'apliques';
  static const _tableInventario = 'inventario';

  @override
  Future<List<Aplique>> getApliques() async {
    final list =
        await _db.from(_table).select().eq('activo', true).order('nombre');
    return list.map<Aplique>((e) => ApliqueMapper.jsonToEntity(e)).toList();
  }

  @override
  Future<List<StockAplique>> getStock(int sucursalId) async {
    final list = await _db
        .from(_tableInventario)
        .select('aplique_id, color_id, stock, colores(nombre, hex)')
        .eq('sucursal_id', sucursalId);
    return list
        .map<StockAplique>((e) => StockApliqueMapper.jsonToEntity(e))
        .toList();
  }
}
