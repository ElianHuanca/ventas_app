import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/venta_aplique_mapper.dart';

void main() {
  group('VentaApliqueMapper.jsonToVentaAplique', () {
    test('mapea una fila de ventas_apliques (fecha TEXT ISO8601)', () {
      final v = VentaApliqueMapper.jsonToVentaAplique({
        'id': 12,
        'fecha': '2026-10-05T14:30:00.000',
        'total': 60,
        'ganancias': 35,
        'descuento': 0,
        'idsucursales': 3,
      });

      expect(v.id, 12);
      expect(v.fecha, DateTime(2026, 10, 5, 14, 30));
    });

    test('fecha inválida o faltante usa la fecha actual', () {
      final antes = DateTime.now().subtract(const Duration(seconds: 1));

      final invalida =
          VentaApliqueMapper.jsonToVentaAplique({'id': 1, 'fecha': 'ayer'});
      final faltante = VentaApliqueMapper.jsonToVentaAplique({'id': 2});

      expect(invalida.fecha.isAfter(antes), isTrue);
      expect(faltante.fecha.isAfter(antes), isTrue);
    });

    test('sin id lanza error (la fila no es una venta)', () {
      expect(
          () => VentaApliqueMapper.jsonToVentaAplique({'fecha': '2026-10-05'}),
          throwsA(isA<TypeError>()));
    });
  });

  group('VentaApliqueMapper.jsonToDetalle', () {
    test('mapea una fila de detalle_ventas_apliques', () {
      final d = VentaApliqueMapper.jsonToDetalle({
        'id': 4,
        'idventa': 12,
        'idapliques': 1,
        'idcolor': 2,
        'nombre': 'Mariposa (Fucsia)',
        'precio': 12,
        'cantidad': 5,
        'total': 60,
        'ganancias': 35,
      });

      expect(d.id, 4);
      expect(d.nombre, 'Mariposa (Fucsia)');
      expect(d.precio, 12.0);
      expect(d.cantidad, 5.0);
      expect(d.total, 60.0);
    });

    test('NUMERIC con decimales se conservan', () {
      final d = VentaApliqueMapper.jsonToDetalle({
        'id': 1,
        'nombre': 'Flor',
        'precio': 12.5,
        'cantidad': 1.5,
        'total': 18.75,
      });

      expect(d.precio, 12.5);
      expect(d.cantidad, 1.5);
      expect(d.total, 18.75);
    });

    test('campos null o faltantes quedan en vacío / 0', () {
      final d = VentaApliqueMapper.jsonToDetalle({
        'id': 1,
        'nombre': null,
        'precio': null,
      });

      expect(d.nombre, '');
      expect(d.precio, 0);
      expect(d.cantidad, 0);
      expect(d.total, 0);
    });
  });
}
