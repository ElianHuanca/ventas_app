// ignore_for_file: file_names
import 'package:textiles_app/config/supabase/supabase_config.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/infrastructure/mappers/detalleVenta_mapper.dart';
import 'package:textiles_app/features/ventas/infrastructure/mappers/venta_mapper.dart';

class DetalleVentasDatasourceImpl extends DetalleVentasDatasource {
  final _db = SupabaseConfig.client;
  static const _table = 'detalle_ventas';

  @override
  Future<List<DetalleVenta>> getDetalleVenta(int idventas) async {
    final list = await _db.from(_table).select().eq('idventa', idventas);
    return list.map((e) => DetalleVentaMapper.jsonToEntity(e)).toList();
  }

  @override
  Future<List<DetalleVenta>> createDetalleVenta(
      List<Map<String, dynamic>> detalleVentasLike, int idventas) async {
    // Upsert atómico en la DB (RPC registrar_detalle_venta) por
    // idventa + idtelas + precio (UNIQUE): si la línea existe suma
    // cantidad/total/ganancias; si no, inserta. No toca los totales de la
    // venta: la venta de la app va por VentasDatasource.registrarVentaTelas
    // (todo junto); esto queda para armar datos (integración, benchmarks).
    final rows = await _db.rpc<List<dynamic>>('registrar_detalle_venta', params: {
      'p_idventa': idventas,
      'p_detalles': detalleVentasLike
          .map((item) => {
                'idtelas': item['idtelas'],
                'nombre': item['nombre'],
                'precio': item['precio'],
                'cantidad': item['cantidad'],
                'total': item['total'],
                'ganancias': item['ganancias'],
              })
          .toList(),
    });
    return rows
        .map((e) => DetalleVentaMapper.jsonToEntity(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Venta?> borrarDetalleVenta(int id) async {
    // Una transacción (RPC borrar_detalle_venta): borrar la línea y restar
    // su total de la venta ya no pueden quedar a medias. Sin la línea (ya
    // borrada) PostgREST devuelve el compuesto con todos los campos en null.
    final row = await _db.rpc<Map<String, dynamic>?>('borrar_detalle_venta',
        params: {'p_id': id});
    if (row == null || row['id'] == null) return null;
    return VentaMapper.jsonToEntity(row);
  }
}
