import 'package:textiles_app/features/ventas/domain/entities/venta.dart';

class VentaMapper {
  static Venta jsonToEntity(Map<String, dynamic> json) {
    return Venta(
      id: json['id'] as int,
      fecha: _parseDateTime(json['fecha']),
      total: _parseDouble(json['total']),
      ganancias: _parseDouble(json['ganancias']),
      idsucursales: json['idsucursales'] as int,
      descuento: _parseDouble(json['descuento']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
