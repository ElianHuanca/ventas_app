import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/infrastructure.dart';

void main() {
  group('StockConVentasMapper (fila de inventario_con_ventas)', () {
    test('lee cada columna', () {
      final s = StockConVentasMapper.jsonToEntity({
        'aplique_id': 4,
        'aplique': 'Flor Petalo Suizo Grande - Bolsa x100 und',
        'color_id': 9,
        'color': 'Rojo',
        'hex': 'C0392B',
        'stock': 3.0,
        'vendidas': 22,
        'vendidas_otras': 1.5,
      });

      expect(s.apliqueId, 4);
      expect(s.aplique, 'Flor Petalo Suizo Grande - Bolsa x100 und');
      expect(s.colorId, 9);
      expect(s.color, 'Rojo');
      expect(s.hex, 'C0392B');
      expect(s.stock, 3.0);
      expect(s.vendidas, 22.0);
      expect(s.vendidasOtras, 1.5);
    });

    test('sin textos ni números usa vacío y 0', () {
      final s = StockConVentasMapper.jsonToEntity({
        'aplique_id': 4,
        'color_id': 9,
        'aplique': null,
        'color': null,
        'hex': null,
        'stock': null,
        'vendidas': null,
        'vendidas_otras': null,
      });

      expect(s.aplique, '');
      expect(s.color, '');
      expect(s.hex, '');
      expect(s.stock, 0);
      expect(s.vendidas, 0);
      expect(s.vendidasOtras, 0);
    });
  });
}
