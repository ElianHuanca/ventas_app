import '../domain.dart';

abstract class SucursalesRepository {
  Future<List<Sucursal>> getSucursales();
  Future<Sucursal> getSucursal(int id);
  Future<Sucursal> createSucursal(Map<String, dynamic> sucursalLike);
  Future<Sucursal> updateSucursal(Map<String, dynamic> sucursalLike,int id);
  Future<bool> deleteSucursal(int id);
  Future<List<TelaSucursal>> getTelasSucursal(int idsucursal);
  Future<void> setTelaSucursal(int idtela, int idsucursal, bool activo);
}
