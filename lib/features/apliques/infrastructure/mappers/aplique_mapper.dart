import '../../domain/domain.dart';

class ApliqueMapper {
  static Aplique jsonToEntity(Map<String, dynamic> json) => Aplique(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        costoFabricacion:
            (json['costo_fabricacion'] as num?)?.toDouble() ?? 0,
        tamanio: json['tamanio'] as String? ?? '',
        anchoCm: (json['ancho_cm'] as num?)?.toDouble(),
        altoCm: (json['alto_cm'] as num?)?.toDouble(),
        activo: json['activo'] as bool? ?? true,
      );
}
