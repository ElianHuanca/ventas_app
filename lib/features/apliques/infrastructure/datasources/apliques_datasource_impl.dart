import 'package:textiles_app/config/supabase/supabase_config.dart';
import '../../domain/domain.dart';
import '../infrastructure.dart';

class ApliquesDatasourceImpl implements ApliquesDatasource {
  final _db = SupabaseConfig.client;
  static const _table = 'apliques';
  static const _tableInventario = 'inventario';
  static const _tableColores = 'colores';
  static const _tableApliqueColores = 'aplique_colores';
  static const _tableProducciones = 'producciones';

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) async {
    var query = _db.from(_table).select();
    if (soloActivos) query = query.eq('activo', true);
    final list = await query.order('nombre');
    return list.map<Aplique>((e) => ApliqueMapper.jsonToEntity(e)).toList();
  }

  @override
  Future<Aplique> createAplique(Map<String, dynamic> apliqueLike) async {
    final data = Map<String, dynamic>.from(apliqueLike)..remove('id');
    final row = await _db.from(_table).insert(data).select().single();
    return ApliqueMapper.jsonToEntity(row);
  }

  @override
  Future<Aplique> updateAplique(Map<String, dynamic> apliqueLike, int id) async {
    final data = Map<String, dynamic>.from(apliqueLike)..remove('id');
    final row =
        await _db.from(_table).update(data).eq('id', id).select().single();
    return ApliqueMapper.jsonToEntity(row);
  }

  @override
  Future<List<StockAplique>> getStock(int sucursalId) async {
    final list = await _db
        .from(_tableInventario)
        .select('aplique_id, color_id, stock, colores(nombre, hex)')
        .eq('sucursal_id', sucursalId)
        .eq('activo', true);
    return list
        .map<StockAplique>((e) => StockApliqueMapper.jsonToEntity(e))
        .toList();
  }

  @override
  Future<List<ColorItem>> getColores() async {
    final list = await _db
        .from(_tableColores)
        .select('id, nombre, hex')
        .eq('activo', true)
        .order('nombre');
    return list
        .map<ColorItem>((e) => ColorItem(
              id: e['id'] as int,
              nombre: e['nombre'] ?? '',
              hex: e['hex'] ?? '',
            ))
        .toList();
  }

  @override
  Future<List<ColorItem>> getColoresAplique(int idaplique) async {
    final list = await _db
        .from(_tableColores)
        .select('id, nombre, hex, aplique_colores(activo)')
        .eq('activo', true)
        .eq('aplique_colores.idaplique', idaplique)
        .order('nombre');
    return list
        .map<ColorItem>((e) => ColorItem(
              id: e['id'] as int,
              nombre: e['nombre'] ?? '',
              hex: e['hex'] ?? '',
              vinculado: e['aplique_colores'] is List &&
                  (e['aplique_colores'] as List)
                      .any((v) => v is Map && (v['activo'] ?? false)),
            ))
        .toList();
  }

  @override
  Future<void> setColorAplique(int idaplique, int idcolor, bool activo) async {
    await _db.from(_tableApliqueColores).upsert({
      'idaplique': idaplique,
      'idcolor': idcolor,
      'activo': activo,
    });
  }

  /// Vincula un aplique+color a una sucursal (fila de inventario).
  /// Si la fila existe (dada de baja), la reactiva; si no, la crea con stock 0.
  @override
  Future<void> addInventario(
      int sucursalId, int apliqueId, int colorId) async {
    final existe = await _db
        .from(_tableInventario)
        .select('stock, activo')
        .eq('sucursal_id', sucursalId)
        .eq('aplique_id', apliqueId)
        .eq('color_id', colorId)
        .maybeSingle();
    if (existe != null) {
      if (existe['activo'] == true) return;
      await _db
          .from(_tableInventario)
          .update({'activo': true})
          .eq('sucursal_id', sucursalId)
          .eq('aplique_id', apliqueId)
          .eq('color_id', colorId);
      return;
    }
    await _db.from(_tableInventario).insert({
      'sucursal_id': sucursalId,
      'aplique_id': apliqueId,
      'color_id': colorId,
      'stock': 0,
    });
  }

  /// Quita la vinculación (baja lógica, activo=false).
  /// Lanza excepción si la fila tiene stock > 0.
  @override
  Future<void> removeInventario(
      int sucursalId, int apliqueId, int colorId) async {
    final row = await _db
        .from(_tableInventario)
        .select('stock')
        .eq('sucursal_id', sucursalId)
        .eq('aplique_id', apliqueId)
        .eq('color_id', colorId)
        .eq('activo', true)
        .maybeSingle();
    if (row == null) return;
    final stock = (row['stock'] as num?)?.toDouble() ?? 0;
    if (stock > 0) {
      throw Exception('Tiene stock ($stock), no se puede quitar');
    }
    await _db
        .from(_tableInventario)
        .update({'activo': false})
        .eq('sucursal_id', sucursalId)
        .eq('aplique_id', apliqueId)
        .eq('color_id', colorId);
  }

  // Sin transacción multi-tabla vía supabase-dart: se hace secuencial,
  // igual que el flujo de ventas. Orden: producción → stock.
  @override
  Future<void> createProduccion({
    required int sucursalId,
    required int apliqueId,
    required int colorId,
    required double cantidad,
  }) async {
    await _db.from(_tableProducciones).insert({
      'sucursal_id': sucursalId,
      'aplique_id': apliqueId,
      'color_id': colorId,
      'cantidad': cantidad,
    });

    final stockRow = await _db
        .from(_tableInventario)
        .select('stock')
        .eq('sucursal_id', sucursalId)
        .eq('aplique_id', apliqueId)
        .eq('color_id', colorId)
        .maybeSingle();
    if (stockRow == null) {
      await _db.from(_tableInventario).insert({
        'sucursal_id': sucursalId,
        'aplique_id': apliqueId,
        'color_id': colorId,
        'stock': cantidad,
      });
    } else {
      final stockActual = (stockRow['stock'] as num?)?.toDouble() ?? 0;
      await _db
          .from(_tableInventario)
          .update({'stock': stockActual + cantidad, 'activo': true})
          .eq('sucursal_id', sucursalId)
          .eq('aplique_id', apliqueId)
          .eq('color_id', colorId);
    }
  }

  @override
  Future<List<Produccion>> getProducciones({int limit = 20}) async {
    final list = await _db
        .from(_tableProducciones)
        .select(
            'id, fecha, cantidad, sucursales(nombre), apliques(nombre), colores(nombre, hex)')
        .order('fecha', ascending: false)
        .order('id', ascending: false)
        .limit(limit);
    return list
        .map<Produccion>((e) => ProduccionMapper.jsonToEntity(e))
        .toList();
  }
}
