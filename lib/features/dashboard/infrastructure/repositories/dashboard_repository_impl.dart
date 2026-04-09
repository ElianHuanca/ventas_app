import 'package:textiles_app/features/dashboard/domain/domain.dart';

class DashboardRepositoryImpl extends DashboardRepository {
  final DashboardDatasource datasource;
  DashboardRepositoryImpl(this.datasource);

  @override
  Future<List<TopProducto>> getTopProductos({
    required DateTime desde,
    required DateTime hasta,
  }) =>
      datasource.getTopProductos(desde: desde, hasta: hasta);

  @override
  Future<ResumenVentas> getResumenVentas({
    required DateTime desde,
    required DateTime hasta,
  }) =>
      datasource.getResumenVentas(desde: desde, hasta: hasta);
}
