import '../../domain/domain.dart';

class VentaApliqueMapper {
  static VentaAplique jsonToVentaAplique(Map<String, dynamic> json) {
    return VentaAplique(
      id: json['id'] as int,
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  static DetalleVentaAplique jsonToDetalle(Map<String, dynamic> json) {
    return DetalleVentaAplique(
      id: json['id'] as int,
      nombre: json['nombre']?.toString() ?? '',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
      precio: (json['precio'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}
