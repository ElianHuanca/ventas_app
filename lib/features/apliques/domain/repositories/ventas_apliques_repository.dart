import '../entities/detalle_venta_aplique.dart';
import '../entities/venta_aplique.dart';

abstract class VentasApliquesRepository {
  Future<int> createVentaAplique({
    required int idsucursales,
    required double total,
    required double ganancias,
    required double descuento,
    required List<Map<String, dynamic>> detalles,
  });
  Future<List<VentaAplique>> getVentasApliques(int idsucursal);
  Future<List<DetalleVentaAplique>> getDetalleVentasApliques(int idventa);
}
