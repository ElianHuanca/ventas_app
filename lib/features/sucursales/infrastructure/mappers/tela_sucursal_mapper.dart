import '../../domain/domain.dart';

class TelaSucursalMapper {
  static TelaSucursal jsonToEntity(Map<String, dynamic> json) {
    final vinculos = json['tela_sucursales'];
    return TelaSucursal(
      idtela: json['id'] as int,
      nombre: json['nombre'] ?? '',
      disponible: vinculos is List &&
          vinculos.any((e) => e is Map && (e['activo'] ?? false)),
    );
  }
}
