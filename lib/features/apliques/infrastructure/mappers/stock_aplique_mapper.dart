import '../../domain/domain.dart';

class StockApliqueMapper {
  static StockAplique jsonToEntity(Map<String, dynamic> json) {
    final colores = json['colores'];
    return StockAplique(
      apliqueId: json['aplique_id'] as int,
      colorId: json['color_id'] as int,
      colorNombre: colores is Map ? (colores['nombre'] as String? ?? '') : '',
      hex: colores is Map ? (colores['hex'] as String? ?? '') : '',
      stock: (json['stock'] as num?)?.toDouble() ?? 0,
    );
  }
}
