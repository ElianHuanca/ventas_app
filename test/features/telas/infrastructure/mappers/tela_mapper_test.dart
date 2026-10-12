import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/infrastructure/mappers/tela_mapper.dart';

void main() {
  group('TelaMapper', () {
    test('mapea un JSON completo', () {
      final Tela tela = TelaMapper.jsonToEntity({
        'id': 3,
        'nombre': 'Lino',
        'precxmen': 100,
        'precxmay': 80.5,
        'precxrollo': 70,
        'precxcompra': 50,
      });
      expect(tela.id, 3);
      expect(tela.nombre, 'Lino');
      expect(tela.precxmen, 100.0);
      expect(tela.precxmay, 80.5);
      expect(tela.precxrollo, 70.0);
      expect(tela.precxcompra, 50.0);
    });

    test('precios null o faltantes quedan en 0', () {
      final Tela tela = TelaMapper.jsonToEntity({'id': 1, 'nombre': 'X'});
      expect(tela.precxmen, 0);
      expect(tela.precxmay, 0);
      expect(tela.precxrollo, 0);
      expect(tela.precxcompra, 0);
    });

    test('nombre faltante queda vacío', () {
      final Tela tela = TelaMapper.jsonToEntity({'id': 1});
      expect(tela.nombre, '');
    });

    test('mapea activo: una tela dada de baja no queda activa', () {
      final Tela tela = TelaMapper.jsonToEntity({'id': 1, 'activo': false});
      expect(tela.activo, false);
    });

    test('activo null o faltante queda activa', () {
      final Tela faltante = TelaMapper.jsonToEntity({'id': 1});
      final Tela nulo = TelaMapper.jsonToEntity({'id': 2, 'activo': null});
      expect(faltante.activo, true);
      expect(nulo.activo, true);
    });
  });
}
