import 'package:textiles_app/config/supabase/supabase_config.dart';
import '../../domain/domain.dart';
import '../infrastructure.dart';

class VentasApliquesDatasourceImpl implements VentasApliquesDatasource {
  final _db = SupabaseConfig.client;
  static const _tableVentas = 'ventas_apliques';
  static const _tableDetalle = 'detalle_ventas_apliques';
  static const _tableInventario = 'inventario';

  // No hay transacción multi-tabla vía supabase-dart: se hace secuencial,
  // igual que el flujo de telas. Orden: venta → detalles → stock.
  @override
  Future<int> createVentaAplique({
    required int idsucursales,
    required double total,
    required double ganancias,
    required double descuento,
    required List<Map<String, dynamic>> detalles,
  }) async {
    final ventaRow = await _db.from(_tableVentas).insert({
      'fecha': DateTime.now().toIso8601String(),
      'total': total,
      'ganancias': ganancias,
      'descuento': descuento,
      'idsucursales': idsucursales,
    }).select('id').single();
    final idventa = ventaRow['id'] as int;

    for (final item in detalles) {
      await _db.from(_tableDetalle).insert({
        'idventa': idventa,
        'idapliques': item['idapliques'],
        'idcolor': item['idcolor'],
        'nombre': item['nombre'],
        'precio': item['precio'],
        'cantidad': item['cantidad'],
        'total': item['total'],
        'ganancias': item['ganancias'],
      });

      final stockRow = await _db
          .from(_tableInventario)
          .select('stock')
          .eq('sucursal_id', idsucursales)
          .eq('aplique_id', item['idapliques'])
          .eq('color_id', item['idcolor'])
          .eq('activo', true)
          .maybeSingle();
      final stockActual = (stockRow?['stock'] as num?)?.toDouble() ?? 0;
      await _db
          .from(_tableInventario)
          .update({
            'stock': stockActual - (item['cantidad'] as num).toDouble(),
          })
          .eq('sucursal_id', idsucursales)
          .eq('aplique_id', item['idapliques'])
          .eq('color_id', item['idcolor'])
          .eq('activo', true);
    }

    return idventa;
  }

  @override
  Future<List<VentaAplique>> getVentasApliques(int idsucursal) async {
    final list = await _db
        .from(_tableVentas)
        .select()
        .eq('idsucursales', idsucursal)
        .order('fecha', ascending: false)
        .limit(10);
    return list
        .map<VentaAplique>((e) => VentaApliqueMapper.jsonToVentaAplique(e))
        .toList();
  }

  @override
  Future<List<DetalleVentaAplique>> getDetalleVentasApliques(
      int idventa) async {
    final list = await _db
        .from(_tableDetalle)
        .select()
        .eq('idventa', idventa)
        .order('id');
    return list
        .map<DetalleVentaAplique>((e) => VentaApliqueMapper.jsonToDetalle(e))
        .toList();
  }
}
