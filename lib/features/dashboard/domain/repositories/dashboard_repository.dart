import '../entities/top_producto.dart';
import '../entities/resumen_ventas.dart';

abstract class DashboardRepository {
  Future<List<TopProducto>> getTopProductos({
    required DateTime desde,
    required DateTime hasta,
  });

  Future<ResumenVentas> getResumenVentas({
    required DateTime desde,
    required DateTime hasta,
  });
}
