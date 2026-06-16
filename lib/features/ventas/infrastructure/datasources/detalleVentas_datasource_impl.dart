// ignore_for_file: file_names
import 'package:textiles_app/config/supabase/supabase_config.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/infrastructure/mappers/detalleVenta_mapper.dart';

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
    final results = <DetalleVenta>[];

    for (final item in detalleVentasLike) {
      // Upsert manual: busca por idventa + idtelas + precio.
      // Si existe, suma cantidad/total/ganancias; si no, inserta.
      final existing = await _db
          .from(_table)
          .select()
          .eq('idventa', idventas)
          .eq('idtelas', item['idtelas'])
          .eq('precio', item['precio'])
          .maybeSingle();

      Map<String, dynamic> row;
      if (existing != null) {
        final id = existing['id'];
        final nuevaCantidad = (existing['cantidad'] as num).toDouble() +
            (item['cantidad'] as num).toDouble();
        final nuevaTotal = ((existing['total'] as num?) ?? 0).toDouble() +
            (item['total'] as num).toDouble();
        final nuevaGanancias =
            ((existing['ganancias'] as num?) ?? 0).toDouble() +
                (item['ganancias'] as num).toDouble();
        row = await _db
            .from(_table)
            .update({
              'cantidad': nuevaCantidad,
              'total': nuevaTotal,
              'ganancias': nuevaGanancias,
            })
            .eq('id', id)
            .select()
            .single();
      } else {
        row = await _db.from(_table).insert({
          'nombre': item['nombre'],
          'precio': item['precio'],
          'cantidad': item['cantidad'],
          'total': item['total'],
          'ganancias': item['ganancias'],
          'idtelas': item['idtelas'],
          'idventa': idventas,
        }).select().single();
      }

      results.add(DetalleVentaMapper.jsonToEntity(row));
    }
    return results;
  }

  @override
  Future<DetalleVenta> deleteDetalleVenta(int id) async {
    final row = await _db.from(_table).select().eq('id', id).maybeSingle();
    if (row == null) throw Exception('Detalle no encontrado');
    final deleted = DetalleVentaMapper.jsonToEntity(row);
    await _db.from(_table).delete().eq('id', id);
    return deleted;
  }
}
