import '../../domain/domain.dart';

class TelaMapper {
  static jsonToEntity(Map<String, dynamic> json) => Tela(
        id: json['id'],
        nombre: json['nombre'] ?? '',
        precxmay: (json['precxmay'] as num?)?.toDouble() ?? 0,
        precxmen: (json['precxmen'] as num?)?.toDouble() ?? 0,
        precxrollo: (json['precxrollo'] as num?)?.toDouble() ?? 0,
        precxcompra: (json['precxcompra'] as num?)?.toDouble() ?? 0,
        idusuarios: json['idusuarios'],
      );
}
