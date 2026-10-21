import '../../domain/domain.dart';

class ProduccionMapper {
  static Produccion jsonToEntity(Map<String, dynamic> json) {
    final produccion = json['producciones'];
    final sucursal = produccion is Map ? produccion['sucursales'] : null;
    final aplique = json['apliques'];
    final color = json['colores'];
    return Produccion(
      id: json['id'] as int,
      fecha: produccion is Map ? (produccion['fecha']?.toString() ?? '') : '',
      sucursalNombre:
          sucursal is Map ? (sucursal['nombre'] as String? ?? '') : '',
      apliqueNombre: aplique is Map ? (aplique['nombre'] as String? ?? '') : '',
      colorNombre: color is Map ? (color['nombre'] as String? ?? '') : '',
      hex: color is Map ? (color['hex'] as String? ?? '') : '',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
    );
  }

  static ProduccionCabecera jsonToCabecera(Map<String, dynamic> json) {
    return ProduccionCabecera(
      id: json['id'] as int,
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
