import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import '../../domain/domain.dart';

class ColoresRepositoryImpl implements ColoresRepository {
  final ColoresDatasource datasource;

  ColoresRepositoryImpl(this.datasource);

  @override
  Future<List<ColorItem>> getColores({bool soloActivos = true}) {
    return datasource.getColores(soloActivos: soloActivos);
  }

  @override
  Future<ColorItem> createColor(Map<String, dynamic> colorLike) {
    return datasource.createColor(colorLike);
  }

  @override
  Future<ColorItem> updateColor(Map<String, dynamic> colorLike, int id) {
    return datasource.updateColor(colorLike, id);
  }

  @override
  Future<bool> deleteColor(int id) {
    return datasource.deleteColor(id);
  }
}
