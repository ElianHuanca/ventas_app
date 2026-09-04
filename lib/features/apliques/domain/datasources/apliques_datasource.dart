import '../entities/aplique.dart';
import '../entities/stock_aplique.dart';

abstract class ApliquesDatasource {
  Future<List<Aplique>> getApliques();
  Future<List<StockAplique>> getStock(int sucursalId);
}
