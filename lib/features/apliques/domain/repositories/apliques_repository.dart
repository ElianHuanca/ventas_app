import '../entities/aplique.dart';
import '../entities/color_item.dart';
import '../entities/produccion.dart';
import '../entities/stock_aplique.dart';

abstract class ApliquesRepository {
  Future<List<Aplique>> getApliques({bool soloActivos = true});
  Future<Aplique> createAplique(Map<String, dynamic> apliqueLike);
  Future<Aplique> updateAplique(Map<String, dynamic> apliqueLike, int id);

  Future<List<StockAplique>> getStock(int sucursalId);
  Future<List<ColorItem>> getColores();
  Future<List<ColorItem>> getColoresAplique(int idaplique);
  Future<void> setColorAplique(int idaplique, int idcolor, bool activo);

  Future<void> addInventario(int sucursalId, int apliqueId, int colorId);
  Future<void> removeInventario(int sucursalId, int apliqueId, int colorId);

  Future<void> createProduccion({
    required int sucursalId,
    required int apliqueId,
    required int colorId,
    required double cantidad,
  });
  Future<List<Produccion>> getProducciones({int limit = 20});
}
