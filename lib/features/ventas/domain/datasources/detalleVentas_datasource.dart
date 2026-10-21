// ignore_for_file: file_names

import '../../domain/domain.dart';


abstract class DetalleVentasDatasource {
  Future<List<DetalleVenta>> getDetalleVenta( int idventas );
  Future<List<DetalleVenta>> createDetalleVenta( List<Map<String,dynamic>> detalleVentasLike ,int idventas);    
  /// Borra la línea y le resta su total y sus ganancias a la venta en una
  /// transacción (RPC `borrar_detalle_venta`). Devuelve la venta con los
  /// totales ya descontados, o null si la línea ya no estaba (la borró otro
  /// dispositivo, o es el reintento de un borrado cuya respuesta se
  /// perdió): no hay nada que descontar.
  Future<Venta?> borrarDetalleVenta( int id );
}

