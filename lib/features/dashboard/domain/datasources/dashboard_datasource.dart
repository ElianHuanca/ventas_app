import '../entities/top_producto.dart';

abstract class DashboardDatasource {
  Future<List<TopProducto>> getTopProductos({
    required DateTime desde,
    required DateTime hasta,
  });
}
