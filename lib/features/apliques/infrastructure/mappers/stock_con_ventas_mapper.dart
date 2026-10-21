import '../../domain/domain.dart';

/// Fila de la RPC `inventario_con_ventas`.
class StockConVentasMapper {
  static StockConVentas jsonToEntity(Map<String, dynamic> json) =>
      StockConVentas(
        apliqueId: json['aplique_id'] as int,
        aplique: json['aplique'] as String? ?? '',
        colorId: json['color_id'] as int,
        color: json['color'] as String? ?? '',
        hex: json['hex'] as String? ?? '',
        stock: (json['stock'] as num?)?.toDouble() ?? 0,
        vendidas: (json['vendidas'] as num?)?.toDouble() ?? 0,
        vendidasOtras: (json['vendidas_otras'] as num?)?.toDouble() ?? 0,
      );
}
