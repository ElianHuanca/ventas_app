import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:textiles_app/config/supabase/supabase_config.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/infrastructure/infrastructure.dart';

class VentasDatasourceImpl extends VentasDatasource {
  final _db = SupabaseConfig.client;
  static const _table = 'ventas';

  @override
  Future<List<Venta>> getVentas(int idsucursal) async {
    final list = await _db
        .from(_table)
        .select()
        .eq('idsucursales', idsucursal)
        .order('fecha', ascending: false)
        .limit(10);
    return list.map((e) => VentaMapper.jsonToEntity(e)).toList();
  }

  @override
  Future<Venta> getVenta(int id) async {
    final row = await _db.from(_table).select().eq('id', id).maybeSingle();
    if (row == null) throw Exception('Venta no encontrada');
    return VentaMapper.jsonToEntity(row);
  }

  @override
  Future<Venta?> getVentaByFecha(int idsucursales, DateTime fecha) async {
    final dateStr = fecha.toIso8601String().substring(0, 10);
    final row = await _db
        .from(_table)
        .select()
        .eq('idsucursales', idsucursales)
        .like('fecha', '$dateStr%')
        .maybeSingle();
    if (row == null) return null;
    return VentaMapper.jsonToEntity(row);
  }

  @override
  Future<Venta> createVentaAhora(int idsucursales) async {
    return createVenta(idsucursales, DateTime.now());
  }

  @override
  Future<Venta> createVenta(int idsucursales, DateTime fecha) async {
    try {
      final row = await _db.from(_table).insert({
        'fecha': fecha.toIso8601String(),
        'total': 0,
        'ganancias': 0,
        'descuento': 0,
        'idsucursales': idsucursales,
      }).select().single();
      return VentaMapper.jsonToEntity(row);
    } on PostgrestException catch (e) {
      // UNIQUE (idsucursales, día): otro dispositivo creó la venta del día
      // entre nuestro getVentaByFecha y este insert → se reutiliza esa.
      if (e.code != '23505') rethrow;
      final existente = await getVentaByFecha(idsucursales, fecha);
      if (existente == null) rethrow;
      return existente;
    }
  }

  @override
  Future<void> deleteVenta(int id) async {
    await _db.from(_table).delete().eq('id', id);
  }

  @override
  Future<Venta> actualizarVenta(Map<String, dynamic> ventaLike, int id) async {
    // Mantiene la convención incremental: los campos numéricos llegan como
    // DELTAS y se suman al valor actual; `fecha` se asigna directamente.
    // La suma la hace la DB en un solo UPDATE (RPC incrementar_venta), así
    // dos dispositivos vendiendo a la vez no pisan el total del otro.
    final row = await _db.rpc<Map<String, dynamic>?>('incrementar_venta', params: {
      'p_id': id,
      'p_total': ventaLike['total'] ?? 0,
      'p_ganancias': ventaLike['ganancias'] ?? 0,
      'p_descuento': ventaLike['descuento'] ?? 0,
      'p_fecha': ventaLike['fecha'],
    });
    // Sin fila, PostgREST devuelve el compuesto con todos los campos en null
    if (row == null || row['id'] == null) {
      throw Exception('Venta no encontrada');
    }
    return VentaMapper.jsonToEntity(row);
  }
}
