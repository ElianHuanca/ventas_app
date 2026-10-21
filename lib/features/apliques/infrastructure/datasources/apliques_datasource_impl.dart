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
  static const _tableDetalleProduccion = 'detalle_produccion';

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) async {
    var query = _db.from(_table).select();
    if (soloActivos) query = query.eq('activo', true);
    final list = await query.order('nombre');
    final apliques =
        list.map<Aplique>((e) => ApliqueMapper.jsonToEntity(e)).toList();
    // Postgres ordena distinguiendo mayúsculas; se reordena sin distinguir
    // (equiv. COLLATE NOCASE, igual que telas)
    apliques.sort((a, b) =>
        a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return apliques;
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

  /// Stock de la sucursal, solo de los colores vinculados a cada aplique.
  /// Lo usan la venta de apliques y Fabricación.
  @override
  Future<List<StockAplique>> getStock(int sucursalId) async {
    final resultados = await Future.wait([
      _db
          .from(_tableInventario)
          .select('aplique_id, color_id, stock, colores(nombre, hex)')
          .eq('sucursal_id', sucursalId)
          .eq('activo', true),
      // inventario no tiene FK a aplique_colores: no se puede embeber
      _db
          .from(_tableApliqueColores)
          .select('idaplique, idcolor')
          .eq('activo', true),
    ]);
    return soloColoresVinculados(resultados[0], resultados[1])
        .map<StockAplique>((e) => StockApliqueMapper.jsonToEntity(e))
        .toList();
  }

  /// Deja las filas de [inventario] cuyo color sigue vinculado al aplique en
  /// [vinculos] (`aplique_colores` activos). Deshabilitar un color en la
  /// pantalla Colores del aplique lo saca de la venta aunque tenga stock,
  /// igual que de Fabricación.
  static List<Map<String, dynamic>> soloColoresVinculados(
    List<Map<String, dynamic>> inventario,
    List<Map<String, dynamic>> vinculos,
  ) {
    final vinculados = {
      for (final v in vinculos) (v['idaplique'], v['idcolor']),
    };
    return inventario
        .where((e) => vinculados.contains((e['aplique_id'], e['color_id'])))
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
              nombre: e['nombre'] as String? ?? '',
              hex: e['hex'] as String? ?? '',
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
    final colores = list
        .map<ColorItem>((e) => ColorItem(
              id: e['id'] as int,
              nombre: e['nombre'] as String? ?? '',
              hex: e['hex'] as String? ?? '',
              vinculado: e['aplique_colores'] is List &&
                  (e['aplique_colores'] as List).any(
                      (v) => v is Map && (v['activo'] as bool? ?? false)),
            ))
        .toList();
    // Postgres ordena distinguiendo mayúsculas; se reordena sin distinguir
    // (mismo criterio que getApliques)
    colores.sort((a, b) =>
        a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return colores;
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

  // RPC inventario_con_ventas: el cliente de Supabase no agrupa ni suma.
  // Compara `fecha` como texto ISO8601 (igual que las del dashboard).
  @override
  Future<List<StockConVentas>> getInventarioConVentas(
    int sucursalId, {
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final rows = await _db.rpc<List<dynamic>>('inventario_con_ventas', params: {
      'p_sucursal_id': sucursalId,
      'desde': DateTime(desde.year, desde.month, desde.day).toIso8601String(),
      // Último instante del día: `fecha` lleva fracción de segundo
      'hasta': DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59, 999, 999)
          .toIso8601String(),
    });
    return rows
        .map<StockConVentas>((e) =>
            StockConVentasMapper.jsonToEntity(e as Map<String, dynamic>))
        .toList();
  }

  // Una sola transacción (RPC registrar_produccion): cabecera del día (una
  // por sucursal+fecha, UNIQUE en la DB), líneas acumuladas por
  // (idproduccion, idaplique, idcolor) y suma al stock de inventario (crea o
  // reactiva la fila). Si ya se fabricó ese aplique+color ese día, se suma
  // la cantidad en vez de crear una línea duplicada.
  @override
  Future<void> createProduccion({
    required int sucursalId,
    required DateTime fecha,
    required List<Map<String, dynamic>> lineas,
  }) async {
    final fechaStr = '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';

    // Devuelve el id de la producción del día; acá no se usa
    await _db.rpc<dynamic>('registrar_produccion', params: {
      'p_sucursal_id': sucursalId,
      'p_fecha': fechaStr,
      'p_lineas': lineas
          .map((linea) => {
                'idaplique': linea['idaplique'],
                'idcolor': linea['idcolor'],
                'cantidad': linea['cantidad'],
              })
          .toList(),
    });
  }

  @override
  Future<List<ProduccionCabecera>> getProducciones(int sucursalId) async {
    final list = await _db
        .from(_tableProducciones)
        .select()
        .eq('sucursal_id', sucursalId)
        .order('fecha', ascending: false)
        .limit(10);
    return list
        .map<ProduccionCabecera>((e) => ProduccionMapper.jsonToCabecera(e))
        .toList();
  }

  @override
  Future<List<Produccion>> getDetalleProduccion(int idproduccion) async {
    final list = await _db
        .from(_tableDetalleProduccion)
        .select(
            'id, cantidad, apliques(nombre), colores(nombre, hex), producciones(fecha, sucursales(nombre))')
        .eq('idproduccion', idproduccion)
        .order('id', ascending: false);
    return list
        .map<Produccion>((e) => ProduccionMapper.jsonToEntity(e))
        .toList();
  }
}
