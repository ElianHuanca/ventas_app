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
      sucursalNombre: sucursal is Map ? (sucursal['nombre'] ?? '') : '',
      apliqueNombre: aplique is Map ? (aplique['nombre'] ?? '') : '',
      colorNombre: color is Map ? (color['nombre'] ?? '') : '',
      hex: color is Map ? (color['hex'] ?? '') : '',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
    );
  }
}
