import 'package:textiles_app/features/ventas/domain/domain.dart';



class VentasRepositoryImpl extends VentasRepository {

  final VentasDatasource datasource;

  VentasRepositoryImpl(this.datasource);

  @override
  Future<List<Venta>> getVentas(int idsucursal) {
    return datasource.getVentas(idsucursal);
  }

  @override
  Future<Venta> createVentaAhora(int idsucursales) {
    return datasource.createVentaAhora(idsucursales);
  }

  @override
  Future<Venta> createVenta(int idsucursales, DateTime fecha) {
    return datasource.createVenta(idsucursales, fecha);
  }
  
  @override
  Future<Venta> getVenta(int id) {
    return datasource.getVenta(id);
  }

  @override
  Future<Venta?> getVentaByFecha(int idsucursales, DateTime fecha) {
    return datasource.getVentaByFecha(idsucursales, fecha);
  }
  
  @override
  Future<Venta> actualizarVenta(Map<String, dynamic> ventaLike, int id) {
    return datasource.actualizarVenta(ventaLike, id);
  }

  @override
  Future<void> deleteVenta(int id) {
    return datasource.deleteVenta(id);
  }
}