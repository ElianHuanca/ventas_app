import '../../domain/domain.dart';

class SucursalMapper {
  static Sucursal jsonToEntity(Map<String, dynamic> json)=> Sucursal(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
  );
}