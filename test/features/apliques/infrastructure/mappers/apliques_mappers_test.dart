import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/aplique_mapper.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/produccion_mapper.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/stock_aplique_mapper.dart';

void main() {
  group('ApliqueMapper', () {
    test('mapea un JSON completo', () {
      final aplique = ApliqueMapper.jsonToEntity({
        'id': 5,
        'nombre': 'Flor',
        'costo_fabricacion': 12.5,
        'tamanio': 'Grande',
        'activo': false,
      });
      expect(aplique.id, 5);
      expect(aplique.nombre, 'Flor');
      expect(aplique.costoFabricacion, 12.5);
      expect(aplique.tamanio, 'Grande');
      expect(aplique.activo, false);
    });

    test('costo_fabricacion int se convierte a double', () {
      final aplique = ApliqueMapper.jsonToEntity({
        'id': 1,
        'nombre': 'X',
        'costo_fabricacion': 7,
      });
      expect(aplique.costoFabricacion, 7.0);
      expect(aplique.costoFabricacion, isA<double>());
    });

    test('campos faltantes usan valores por defecto', () {
      final aplique = ApliqueMapper.jsonToEntity({'id': 2});
      expect(aplique.nombre, '');
      expect(aplique.costoFabricacion, 0);
      expect(aplique.tamanio, '');
      expect(aplique.activo, true);
    });

    test('campos null usan valores por defecto', () {
      final aplique = ApliqueMapper.jsonToEntity({
        'id': 3,
        'nombre': null,
        'costo_fabricacion': null,
        'tamanio': null,
        'activo': null,
      });
      expect(aplique.nombre, '');
      expect(aplique.costoFabricacion, 0);
      expect(aplique.tamanio, '');
      expect(aplique.activo, true);
    });

    test('sin id lanza error', () {
      expect(() => ApliqueMapper.jsonToEntity({'nombre': 'X'}),
          throwsA(isA<TypeError>()));
    });
  });

  group('StockApliqueMapper', () {
    test('mapea con join de colores', () {
      final stock = StockApliqueMapper.jsonToEntity({
        'aplique_id': 1,
        'color_id': 2,
        'stock': 8,
        'colores': {'nombre': 'Rojo', 'hex': '#FF0000'},
      });
      expect(stock.apliqueId, 1);
      expect(stock.colorId, 2);
      expect(stock.colorNombre, 'Rojo');
      expect(stock.hex, '#FF0000');
      expect(stock.stock, 8.0);
    });

    test('sin join de colores deja nombre y hex vacíos', () {
      final stock = StockApliqueMapper.jsonToEntity({
        'aplique_id': 1,
        'color_id': 2,
        'stock': 3.5,
        'colores': null,
      });
      expect(stock.colorNombre, '');
      expect(stock.hex, '');
      expect(stock.stock, 3.5);
    });

    test('stock faltante o null es 0', () {
      final stock = StockApliqueMapper.jsonToEntity({
        'aplique_id': 1,
        'color_id': 2,
      });
      expect(stock.stock, 0);
    });
  });

  group('ProduccionMapper', () {
    test('mapea con todos los joins (detalle_produccion -> producciones -> sucursales)', () {
      final p = ProduccionMapper.jsonToEntity({
        'id': 10,
        'cantidad': 4,
        'producciones': {
          'fecha': '2024-05-01',
          'sucursales': {'nombre': 'Centro'},
        },
        'apliques': {'nombre': 'Estrella'},
        'colores': {'nombre': 'Azul', 'hex': '#0000FF'},
      });
      expect(p.id, 10);
      expect(p.fecha, '2024-05-01');
      expect(p.sucursalNombre, 'Centro');
      expect(p.apliqueNombre, 'Estrella');
      expect(p.colorNombre, 'Azul');
      expect(p.hex, '#0000FF');
      expect(p.cantidad, 4.0);
    });

    test('joins null o no-Map dejan strings vacíos', () {
      final p = ProduccionMapper.jsonToEntity({
        'id': 1,
        'cantidad': null,
        'producciones': null,
        'apliques': 'no-es-map',
        'colores': null,
      });
      expect(p.fecha, '');
      expect(p.sucursalNombre, '');
      expect(p.apliqueNombre, '');
      expect(p.colorNombre, '');
      expect(p.hex, '');
      expect(p.cantidad, 0);
    });

    test('sucursal null dentro de producciones deja el nombre vacío', () {
      final p = ProduccionMapper.jsonToEntity({
        'id': 1,
        'producciones': {'fecha': '2024-05-01', 'sucursales': null},
      });
      expect(p.fecha, '2024-05-01');
      expect(p.sucursalNombre, '');
    });

    test('fecha se convierte a string aunque venga como otro tipo', () {
      final p = ProduccionMapper.jsonToEntity({
        'id': 1,
        'producciones': {'fecha': 12345},
      });
      expect(p.fecha, '12345');
    });
  });

  group('ProduccionMapper.jsonToCabecera', () {
    test('mapea una fila de producciones', () {
      final cab = ProduccionMapper.jsonToCabecera({
        'id': 3,
        'fecha': '2024-05-10',
        'sucursal_id': 1,
      });
      expect(cab.id, 3);
      expect(cab.fecha, DateTime(2024, 5, 10));
    });

    test('fecha inválida o faltante usa la fecha actual', () {
      final cab = ProduccionMapper.jsonToCabecera({'id': 1, 'fecha': null});
      final hoy = DateTime.now();
      expect(cab.fecha.year, hoy.year);
      expect(cab.fecha.month, hoy.month);
      expect(cab.fecha.day, hoy.day);
    });
  });
}
