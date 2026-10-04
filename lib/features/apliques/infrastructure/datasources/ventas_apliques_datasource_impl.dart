import 'package:textiles_app/config/supabase/supabase_config.dart';
import '../../domain/domain.dart';
import '../infrastructure.dart';

class VentasApliquesDatasourceImpl implements VentasApliquesDatasource {
  final _db = SupabaseConfig.client;
  static const _tableVentas = 'ventas_apliques';
  static const _tableDetalle = 'detalle_ventas_apliques';

  // Venta + detalles + descuento de stock en una sola transacción (RPC
  // crear_venta_apliques): si alguna línea no tiene stock suficiente, falla
  // entera y no queda nada guardado. Dos dispositivos vendiendo el mismo
  // aplique+color a la vez se serializan en la DB.
  @override
  Future<int> createVentaAplique({
    required int idsucursales,
    required double total,
    required double ganancias,
    required double descuento,
    required List<Map<String, dynamic>> detalles,
  }) async {
    final idventa = await _db.rpc('crear_venta_apliques', params: {
      'p_idsucursales': idsucursales,
      'p_fecha': DateTime.now().toIso8601String(),
      'p_total': total,
      'p_ganancias': ganancias,
      'p_descuento': descuento,
      'p_detalles': detalles
          .map((item) => {
                'idapliques': item['idapliques'],
                'idcolor': item['idcolor'],
                'nombre': item['nombre'],
                'precio': item['precio'],
                'cantidad': item['cantidad'],
                'total': item['total'],
                'ganancias': item['ganancias'],
              })
          .toList(),
    });
    return idventa as int;
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
