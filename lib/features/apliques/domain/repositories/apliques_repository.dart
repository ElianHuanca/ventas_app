import '../entities/aplique.dart';
import '../entities/stock_aplique.dart';

abstract class ApliquesRepository {
  Future<List<Aplique>> getApliques();
  Future<List<StockAplique>> getStock(int sucursalId);
}
