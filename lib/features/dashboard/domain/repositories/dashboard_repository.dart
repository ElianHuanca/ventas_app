import '../entities/top_producto.dart';

abstract class DashboardRepository {
  Future<List<TopProducto>> getTopProductos({
    required DateTime desde,
    required DateTime hasta,
  });
}
