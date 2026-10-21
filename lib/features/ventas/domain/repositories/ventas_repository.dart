import '../entities/venta.dart';


abstract class VentasRepository {

  Future<List<Venta>> getVentas(int idsucursal);
  Future<Venta> getVenta(int id);
  Future<Venta?> getVentaByFecha(int idsucursales, DateTime fecha);
  Future<Venta> createVentaAhora(int idsucursales);
  Future<Venta> createVenta(int idsucursales, DateTime fecha);
  Future<Venta> actualizarVenta(Map<String,dynamic> ventaLike,int id);
  Future<void> deleteVenta(int id);

  /// Ver [VentasDatasource.registrarVentaTelas].
  Future<int> registrarVentaTelas({
    required int idsucursal,
    required DateTime fecha,
    required List<Map<String, dynamic>> detalles,
    required double descuento,
    String? idOperacion,
  });
}

