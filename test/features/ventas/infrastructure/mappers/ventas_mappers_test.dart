import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/ventas/infrastructure/mappers/detalleVenta_mapper.dart';
import 'package:textiles_app/features/ventas/infrastructure/mappers/venta_mapper.dart';

void main() {
  group('VentaMapper', () {
    test('mapea un JSON completo', () {
      final v = VentaMapper.jsonToEntity({
        'id': 1,
        'fecha': '2024-03-15T08:30:00',
        'total': 250,
        'ganancias': '100.5',
        'descuento': 10,
        'idsucursales': 2,
      });
      expect(v.id, 1);
      expect(v.fecha, DateTime(2024, 3, 15, 8, 30));
      expect(v.total, 250.0);
      expect(v.ganancias, 100.5);
      expect(v.descuento, 10.0);
      expect(v.idsucursales, 2);
    });

    test('numéricos null quedan en 0', () {
      final v = VentaMapper.jsonToEntity({
        'id': 1,
        'fecha': '2024-01-01',
        'total': null,
        'ganancias': null,
        'descuento': null,
        'idsucursales': 1,
      });
      expect(v.total, 0);
      expect(v.ganancias, 0);
      expect(v.descuento, 0);
    });

    test('fecha inválida o null cae a DateTime.now()', () {
      final antes = DateTime.now();
      final v = VentaMapper.jsonToEntity({
        'id': 1,
        'fecha': 'no-es-fecha',
        'idsucursales': 1,
      });
      expect(
          v.fecha.isAfter(antes.subtract(const Duration(seconds: 2))), true);
    });

    test('fecha como DateTime se respeta', () {
      final fecha = DateTime(2023, 12, 25);
      final v = VentaMapper.jsonToEntity({
        'id': 1,
        'fecha': fecha,
        'idsucursales': 1,
      });
      expect(v.fecha, fecha);
    });
  });

  group('DetalleVentaMapper', () {
    test('mapea un JSON completo', () {
      final d = DetalleVentaMapper.jsonToEntity({
        'id': 5,
        'nombre': 'Lino',
        'precio': 100,
        'cantidad': 2.5,
        'total': 250,
        'ganancias': 50,
        'idtelas': 3,
      });
      expect(d.id, 5);
      expect(d.nombre, 'Lino');
      expect(d.precio, 100.0);
      expect(d.cantidad, 2.5);
      expect(d.total, 250.0);
      expect(d.ganancias, 50.0);
      expect(d.idtelas, 3);
    });

    test('parsea strings numéricos', () {
      final d = DetalleVentaMapper.jsonToEntity({
        'idtelas': 1,
        'precio': '99.9',
        'cantidad': '3',
        'total': '299.7',
        'ganancias': 'x',
      });
      expect(d.precio, 99.9);
      expect(d.cantidad, 3.0);
      expect(d.total, 299.7);
      expect(d.ganancias, 0); // no parseable -> 0
    });

    test('campos opcionales null quedan null o 0', () {
      final d = DetalleVentaMapper.jsonToEntity({
        'id': null,
        'nombre': null,
        'precio': null,
        'cantidad': null,
        'idtelas': 4,
      });
      expect(d.id, isNull);
      expect(d.nombre, isNull);
      expect(d.precio, 0);
      expect(d.cantidad, 0);
    });

    test('sin idtelas lanza error', () {
      expect(() => DetalleVentaMapper.jsonToEntity({'precio': 10}),
          throwsA(isA<TypeError>()));
    });
  });
}
