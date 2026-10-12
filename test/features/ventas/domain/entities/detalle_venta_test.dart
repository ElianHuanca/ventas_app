import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/ventas/domain/entities/detalleVenta.dart';
import 'package:textiles_app/features/ventas/infrastructure/mappers/detalleVenta_mapper.dart';

void main() {
  group('DetalleVenta.toJson', () {
    test('usa los nombres de columna de detalle_ventas', () {
      const d = DetalleVenta(
        id: 5,
        nombre: 'Lino',
        precio: 25,
        cantidad: 2.5,
        total: 62.5,
        ganancias: 25,
        idtelas: 3,
      );

      expect(d.toJson(), {
        'id': 5,
        'nombre': 'Lino',
        'precio': 25.0,
        'cantidad': 2.5,
        'total': 62.5,
        'idtelas': 3,
        'ganancias': 25.0,
      });
    });

    test('una línea nueva (sin id ni totales) los deja en null', () {
      const d = DetalleVenta(precio: 10, cantidad: 1, idtelas: 7);

      final json = d.toJson();

      expect(json['id'], isNull);
      expect(json['nombre'], isNull);
      expect(json['total'], isNull);
      expect(json['ganancias'], isNull);
      expect(json['idtelas'], 7);
    });

    test('ida y vuelta con DetalleVentaMapper conserva los valores', () {
      const original = DetalleVenta(
        id: 1,
        nombre: 'Seda',
        precio: 30,
        cantidad: 1.25,
        total: 37.5,
        ganancias: 12.5,
        idtelas: 9,
      );

      final copia = DetalleVentaMapper.jsonToEntity(original.toJson());

      expect(copia.toJson(), original.toJson());
    });
  });
}
