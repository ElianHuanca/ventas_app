import '../../domain/domain.dart';

class TelaMapper {
  static Tela jsonToEntity(Map<String, dynamic> json) => Tela(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        precxmay: (json['precxmay'] as num?)?.toDouble() ?? 0,
        precxmen: (json['precxmen'] as num?)?.toDouble() ?? 0,
        precxrollo: (json['precxrollo'] as num?)?.toDouble() ?? 0,
        precxcompra: (json['precxcompra'] as num?)?.toDouble() ?? 0,
        activo: json['activo'] as bool? ?? true,
      );
}
