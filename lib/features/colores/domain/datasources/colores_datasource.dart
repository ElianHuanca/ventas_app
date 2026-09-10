import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';

abstract class ColoresDatasource {
  Future<List<ColorItem>> getColores({bool soloActivos = true});
  Future<ColorItem> createColor(Map<String, dynamic> colorLike);
  Future<ColorItem> updateColor(Map<String, dynamic> colorLike, int id);

  /// Baja lógica: activo = false (nunca DELETE físico).
  Future<bool> deleteColor(int id);
}
