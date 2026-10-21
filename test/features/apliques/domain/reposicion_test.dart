import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';

StockConVentas _item({
  String aplique = 'Flor',
  String color = 'Rojo',
  double stock = 0,
  double vendidas = 0,
  double vendidasOtras = 0,
}) =>
    StockConVentas(
      apliqueId: 1,
      aplique: aplique,
      colorId: 1,
      color: color,
      hex: 'FF0000',
      stock: stock,
      vendidas: vendidas,
      vendidasOtras: vendidasOtras,
    );

Reposicion _propia(StockConVentas s) => Reposicion.de(s, estimada: false);

void main() {
  group('Reposicion.de', () {
    test('lo que no se vendió en la ventana no falta, aunque esté en 0', () {
      final r = _propia(_item(stock: 0, vendidas: 0));

      expect(r.porSemana, 0);
      expect(r.minimo, 0);
      expect(r.hacer, 0);
      expect(r.faltante, isFalse);
      expect(r.semanasDeStock, double.infinity);
    });

    test('mínimo = venta de 2,5 semanas (1,5 de entrega + 1 de colchón)', () {
      // 8 en 4 semanas = 2 por semana → 5
      final r = _propia(_item(stock: 20, vendidas: 8));

      expect(r.porSemana, 2);
      expect(r.minimo, 5);
    });

    test('el mínimo redondea para arriba', () {
      // 12 en 4 semanas = 3 por semana → 7,5 → 8
      expect(_propia(_item(vendidas: 12)).minimo, 8);
      // 1 en 4 semanas → 0,625 → 1
      expect(_propia(_item(vendidas: 1)).minimo, 1);
    });

    test('un mínimo exacto no sube por coma flotante', () {
      // 8 × 2,5 / 4 = 5 exacto (0.2 × 2.5 × 10 daría 5.000000001 → 6)
      for (final (vendidas, minimo) in [(8.0, 5), (16.0, 10), (24.0, 15)]) {
        expect(_propia(_item(vendidas: vendidas)).minimo, minimo,
            reason: '$vendidas vendidas');
      }
    });

    test('falta con el stock igual al mínimo, no con uno más', () {
      expect(_propia(_item(stock: 5, vendidas: 8)).faltante, isTrue);
      expect(_propia(_item(stock: 6, vendidas: 8)).faltante, isFalse);
    });

    test('se pide hasta el doble del mínimo', () {
      // mínimo 5: con 3 se hacen 7, con 0 se hacen 10
      expect(_propia(_item(stock: 3, vendidas: 8)).hacer, 7);
      expect(_propia(_item(stock: 0, vendidas: 8)).hacer, 10);
    });

    test('con stock con decimales, lo que hay que hacer redondea para arriba',
        () {
      // mínimo 5, quedan 2,5 → 7,5 → 8
      expect(_propia(_item(stock: 2.5, vendidas: 8)).hacer, 8);
    });

    test('el caso de Ramada: vende 9 por semana y quedan 3', () {
      // 36,4 en 4 semanas = 9,1 por semana → mínimo 22,75 → 23; hacer 46 - 3
      final r = _propia(_item(stock: 3, vendidas: 36.4));

      expect(r.minimo, 23);
      expect(r.hacer, 43);
      expect(r.semanasDeStock, closeTo(3 / 9.1, 1e-9));
    });

    test('estimada usa lo que venden las otras sucursales', () {
      final s = _item(stock: 0, vendidas: 0, vendidasOtras: 8);

      expect(Reposicion.de(s, estimada: true).hacer, 10);
      expect(Reposicion.de(s, estimada: false).hacer, 0);
    });
  });

  group('ReglaReposicion.aplicar', () {
    test('si la sucursal no vendió nada, estima con las otras', () {
      final items = ReglaReposicion.aplicar([
        _item(color: 'Rojo', vendidasOtras: 8),
        _item(color: 'Azul', vendidasOtras: 0),
      ]);

      expect(items.every((r) => r.estimada), isTrue);
      expect(items.where((r) => r.faltante).map((r) => r.item.color),
          ['Rojo']);
    });

    test('con alguna venta propia no estima: ignora a las otras', () {
      final items = ReglaReposicion.aplicar([
        _item(color: 'Rojo', vendidas: 1, stock: 10),
        _item(color: 'Azul', vendidas: 0, vendidasOtras: 40),
      ]);

      expect(items.any((r) => r.estimada), isFalse);
      expect(items.any((r) => r.faltante), isFalse);
    });

    test('faltantes primero, por aplique y de más a menos para hacer', () {
      final items = ReglaReposicion.aplicar([
        _item(aplique: 'A', color: 'sin ventas', vendidas: 0),
        // mínimo 5, quedan 4 → hacer 6
        _item(aplique: 'C', color: 'hacer 6', vendidas: 8, stock: 4),
        // mínimo 25, quedan 5 → hacer 45
        _item(aplique: 'C', color: 'hacer 45', vendidas: 40, stock: 5),
        // mínimo 5, quedan 0 → hacer 10
        _item(aplique: 'B', color: 'hacer 10', vendidas: 8),
        // sobra: 1 por semana, quedan 50
        _item(aplique: 'B', color: 'sobra', vendidas: 4, stock: 50),
      ]);

      expect(items.map((r) => r.item.color),
          ['hacer 10', 'hacer 45', 'hacer 6', 'sin ventas', 'sobra']);
    });

    test('lo que no falta va por aplique y color, sin distinguir mayúsculas',
        () {
      final items = ReglaReposicion.aplicar([
        _item(aplique: 'mariposa', color: 'rojo', vendidas: 1, stock: 99),
        _item(aplique: 'Flor', color: 'verde', vendidas: 1, stock: 99),
        _item(aplique: 'Flor', color: 'Azul', vendidas: 1, stock: 99),
      ]);

      expect(items.map((r) => '${r.item.aplique} ${r.item.color}'),
          ['Flor Azul', 'Flor verde', 'mariposa rojo']);
    });

    test('el color también se ordena sin distinguir mayúsculas', () {
      // "Verde" < "azul" distinguiendo mayúsculas: el orden de entrada no
      // tiene que importar
      for (final entrada in [
        ['Verde', 'azul'],
        ['azul', 'Verde'],
      ]) {
        final items = ReglaReposicion.aplicar([
          for (final color in entrada)
            _item(color: color, vendidas: 1, stock: 99),
        ]);

        expect(items.map((r) => r.item.color), ['azul', 'Verde'],
            reason: 'entrada $entrada');
      }
    });

    test('un inventario vacío no tiene nada que reponer', () {
      expect(ReglaReposicion.aplicar(const []), isEmpty);
    });
  });
}
