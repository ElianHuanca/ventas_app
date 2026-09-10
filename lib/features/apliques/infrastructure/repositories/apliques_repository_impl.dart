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
  Future<void> createProduccion({
    required int sucursalId,
    required int apliqueId,
    required int colorId,
    required double cantidad,
  }) {
    return datasource.createProduccion(
      sucursalId: sucursalId,
      apliqueId: apliqueId,
      colorId: colorId,
      cantidad: cantidad,
    );
  }

  @override
  Future<List<Produccion>> getProducciones({int limit = 20}) {
    return datasource.getProducciones(limit: limit);
  }
}
