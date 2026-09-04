import 'package:textiles_app/features/apliques/domain/domain.dart';

class ApliquesRepositoryImpl extends ApliquesRepository {
  final ApliquesDatasource datasource;

  ApliquesRepositoryImpl(this.datasource);

  @override
  Future<List<Aplique>> getApliques() {
    return datasource.getApliques();
  }

  @override
  Future<List<StockAplique>> getStock(int sucursalId) {
    return datasource.getStock(sucursalId);
  }
}
