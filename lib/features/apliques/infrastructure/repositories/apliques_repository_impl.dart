import 'package:textiles_app/features/apliques/domain/domain.dart';

class ApliquesRepositoryImpl extends ApliquesRepository {
  final ApliquesDatasource datasource;

  ApliquesRepositoryImpl(this.datasource);

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) {
    return datasource.getApliques(soloActivos: soloActivos);
  }

  @override
  Future<Aplique> createAplique(Map<String, dynamic> apliqueLike) {
    return datasource.createAplique(apliqueLike);
  }

  @override
  Future<Aplique> updateAplique(Map<String, dynamic> apliqueLike, int id) {
    return datasource.updateAplique(apliqueLike, id);
  }

  @override
  Future<List<StockAplique>> getStock(int sucursalId) {
    return datasource.getStock(sucursalId);
  }

  @override
  Future<List<ColorItem>> getColores() {
    return datasource.getColores();
  }

  @override
  Future<List<ColorItem>> getColoresAplique(int idaplique) {
    return datasource.getColoresAplique(idaplique);
  }

  @override
  Future<void> setColorAplique(int idaplique, int idcolor, bool activo) {
    return datasource.setColorAplique(idaplique, idcolor, activo);
  }

  @override
  Future<void> addInventario(int sucursalId, int apliqueId, int colorId) {
    return datasource.addInventario(sucursalId, apliqueId, colorId);
  }

  @override
  Future<void> removeInventario(int sucursalId, int apliqueId, int colorId) {
    return datasource.removeInventario(sucursalId, apliqueId, colorId);
  }

  @override
  Future<List<StockConVentas>> getInventarioConVentas(
    int sucursalId, {
    required DateTime desde,
    required DateTime hasta,
  }) {
    return datasource.getInventarioConVentas(sucursalId,
        desde: desde, hasta: hasta);
  }

  @override
  Future<void> createProduccion({
    required int sucursalId,
    required DateTime fecha,
    required List<Map<String, dynamic>> lineas,
    String? idOperacion,
  }) {
    return datasource.createProduccion(
      sucursalId: sucursalId,
      fecha: fecha,
      lineas: lineas,
      idOperacion: idOperacion,
    );
  }

  @override
  Future<List<ProduccionCabecera>> getProducciones(int sucursalId) {
    return datasource.getProducciones(sucursalId);
  }

  @override
  Future<List<Produccion>> getDetalleProduccion(int idproduccion) {
    return datasource.getDetalleProduccion(idproduccion);
  }
}
