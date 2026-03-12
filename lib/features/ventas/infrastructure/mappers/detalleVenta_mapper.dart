// ignore_for_file: file_names

import 'package:textiles_app/features/ventas/domain/domain.dart';

class DetalleVentaMapper {
  static DetalleVenta jsonToEntity(Map<String, dynamic> json) {
    return DetalleVenta(
      id: json['id'] as int?,
      nombre: json['nombre'] as String?,
      cantidad: _parseDouble(json['cantidad']),
      precio: _parseDouble(json['precio']),
      total: _parseDouble(json['total']),
      ganancias: _parseDouble(json['ganancias']),
      idtelas: json['idtelas'] as int,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
