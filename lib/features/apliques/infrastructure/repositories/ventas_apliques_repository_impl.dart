import 'package:textiles_app/features/apliques/domain/domain.dart';

class VentasApliquesRepositoryImpl extends VentasApliquesRepository {
  final VentasApliquesDatasource datasource;

  VentasApliquesRepositoryImpl(this.datasource);

  @override
  Future<int> createVentaAplique({
    required int idsucursales,
    required double total,
    required double ganancias,
    required double descuento,
    required List<Map<String, dynamic>> detalles,
    String? idOperacion,
  }) {
    return datasource.createVentaAplique(
      idsucursales: idsucursales,
      total: total,
      ganancias: ganancias,
      descuento: descuento,
      detalles: detalles,
      idOperacion: idOperacion,
    );
  }

  @override
  Future<List<VentaAplique>> getVentasApliques(int idsucursal) {
    return datasource.getVentasApliques(idsucursal);
  }

  @override
  Future<List<DetalleVentaAplique>> getDetalleVentasApliques(int idventa) {
    return datasource.getDetalleVentasApliques(idventa);
  }
}
