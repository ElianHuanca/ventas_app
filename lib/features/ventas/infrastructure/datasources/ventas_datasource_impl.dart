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
        .order('fecha', ascending: false);
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
    final row = await _db.from(_table).insert({
      'fecha': fecha.toIso8601String(),
      'total': 0,
      'ganancias': 0,
      'descuento': 0,
      'idsucursales': idsucursales,
    }).select().single();
    return VentaMapper.jsonToEntity(row);
  }

  @override
  Future<void> deleteVenta(int id) async {
    await _db.from(_table).delete().eq('id', id);
  }

  @override
  Future<Venta> actualizarVenta(Map<String, dynamic> ventaLike, int id) async {
    // Mantiene la convención incremental: los campos numéricos llegan como
    // DELTAS y se suman al valor actual; `fecha` se asigna directamente.
    final delta = Map<String, dynamic>.from(ventaLike)..remove('id');

    final current =
        await _db.from(_table).select().eq('id', id).single();

    final update = <String, dynamic>{};
    delta.forEach((key, value) {
      if (key == 'fecha') {
        update[key] = value;
      } else {
        final actual = (current[key] as num?)?.toDouble() ?? 0.0;
        final sumando = (value as num?)?.toDouble() ?? 0.0;
        update[key] = actual + sumando;
      }
    });

    final row =
        await _db.from(_table).update(update).eq('id', id).select().single();
    return VentaMapper.jsonToEntity(row);
  }
}
