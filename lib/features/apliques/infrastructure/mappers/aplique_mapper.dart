import '../../domain/domain.dart';

class ApliqueMapper {
  static Aplique jsonToEntity(Map<String, dynamic> json) => Aplique(
        id: json['id'] as int,
        nombre: json['nombre'] ?? '',
        costoFabricacion:
            (json['costo_fabricacion'] as num?)?.toDouble() ?? 0,
        tamanio: json['tamanio'] ?? '',
        activo: json['activo'] ?? true,
      );
}
