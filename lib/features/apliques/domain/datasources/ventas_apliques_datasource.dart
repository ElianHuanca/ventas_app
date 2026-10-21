import '../entities/detalle_venta_aplique.dart';
import '../entities/venta_aplique.dart';

abstract class VentasApliquesDatasource {
  /// [idOperacion]: clave de idempotencia del envío (`ClaveDeOperacion`).
  /// Con la misma clave, un reintento no vuelve a vender (la base devuelve
  /// la venta de la primera vez).
  Future<int> createVentaAplique({
    required int idsucursales,
    required double total,
    required double ganancias,
    required double descuento,
    required List<Map<String, dynamic>> detalles,
    String? idOperacion,
  });
  Future<List<VentaAplique>> getVentasApliques(int idsucursal);
  Future<List<DetalleVentaAplique>> getDetalleVentasApliques(int idventa);
}
