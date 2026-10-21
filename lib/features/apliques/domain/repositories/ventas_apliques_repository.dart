import '../entities/detalle_venta_aplique.dart';
import '../entities/venta_aplique.dart';

abstract class VentasApliquesRepository {
  /// Ver [VentasApliquesDatasource.createVentaAplique].
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
