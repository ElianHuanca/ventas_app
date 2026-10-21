import '../entities/venta.dart';


abstract class VentasDatasource {
  Future<List<Venta>> getVentas(int idsucursal);
  Future<Venta> getVenta(int id);
  Future<Venta?> getVentaByFecha(int idsucursales, DateTime fecha);
  Future<Venta> createVentaAhora(int idsucursales);
  Future<Venta> createVenta(int idsucursales, DateTime fecha);
  Future<Venta> actualizarVenta(Map<String,dynamic> ventaLike,int id);
  Future<void> deleteVenta(int id);

  /// Registra el carrito entero en una transacción (RPC
  /// `registrar_venta_telas`): la venta del día de la sucursal (la crea o
  /// la reusa), las líneas acumuladas por tela+precio y a la venta el total
  /// y las ganancias de esas líneas y el [descuento]. [idOperacion] es la
  /// clave de idempotencia del envío (`ClaveDeOperacion`): con la misma, un
  /// reintento no vuelve a sumar. Devuelve el id de la venta.
  Future<int> registrarVentaTelas({
    required int idsucursal,
    required DateTime fecha,
    required List<Map<String, dynamic>> detalles,
    required double descuento,
    String? idOperacion,
  });
}

