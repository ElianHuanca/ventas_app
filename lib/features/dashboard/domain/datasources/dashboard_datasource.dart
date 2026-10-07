import '../entities/top_producto.dart';
import '../entities/resumen_ventas.dart';

abstract class DashboardDatasource {
  Future<List<TopProducto>> getTopProductos({
    required DateTime desde,
    required DateTime hasta,
  });

  Future<List<TopProducto>> getTopApliques({
    required DateTime desde,
    required DateTime hasta,
  });

  Future<ResumenVentas> getResumenVentas({
    required DateTime desde,
    required DateTime hasta,
  });

  Future<ResumenVentas> getResumenVentasApliques({
    required DateTime desde,
    required DateTime hasta,
  });
}
