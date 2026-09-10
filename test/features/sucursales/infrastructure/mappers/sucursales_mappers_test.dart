import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/infrastructure/mappers/sucursal_mapper.dart';
import 'package:textiles_app/features/sucursales/infrastructure/mappers/tela_sucursal_mapper.dart';

void main() {
  group('SucursalMapper', () {
    test('mapea id y nombre', () {
      final s = SucursalMapper.jsonToEntity({'id': 1, 'nombre': 'Centro'});
      expect(s.id, 1);
      expect(s.nombre, 'Centro');
    });

    test('nombre null devuelve vacío (mapper null-safe)', () {
      final s = SucursalMapper.jsonToEntity({'id': 1, 'nombre': null});
      expect(s.nombre, '');
    });
  });

  group('TelaSucursalMapper', () {
    test('disponible true cuando hay un vínculo activo', () {
      final t = TelaSucursalMapper.jsonToEntity({
        'id': 7,
        'nombre': 'Algodón',
        'tela_sucursales': [
          {'activo': false},
          {'activo': true},
        ],
      });
      expect(t.idtela, 7);
      expect(t.nombre, 'Algodón');
      expect(t.disponible, true);
    });

    test('disponible false cuando ningún vínculo está activo', () {
      final t = TelaSucursalMapper.jsonToEntity({
        'id': 7,
        'nombre': 'Algodón',
        'tela_sucursales': [
          {'activo': false},
        ],
      });
      expect(t.disponible, false);
    });

    test('disponible false cuando el embed es null o no es lista', () {
      expect(
        TelaSucursalMapper.jsonToEntity(
                {'id': 1, 'nombre': 'X', 'tela_sucursales': null})
            .disponible,
        false,
      );
      expect(
        TelaSucursalMapper.jsonToEntity(
                {'id': 1, 'nombre': 'X', 'tela_sucursales': 'foo'})
            .disponible,
        false,
      );
    });

    test('nombre faltante queda vacío', () {
      final t = TelaSucursalMapper.jsonToEntity({'id': 1});
      expect(t.nombre, '');
      expect(t.disponible, false);
    });
  });
}
