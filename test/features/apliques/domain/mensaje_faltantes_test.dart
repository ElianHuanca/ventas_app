import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';

Reposicion _faltante(String aplique, String color, double stock,
        double vendidas) =>
    Reposicion.de(
      StockConVentas(
        apliqueId: 1,
        aplique: aplique,
        colorId: 1,
        color: color,
        hex: '',
        stock: stock,
        vendidas: vendidas,
      ),
      estimada: false,
    );

void main() {
  group('mensajeFaltantes', () {
    test('título con la sucursal y la fecha, una línea por faltante y total',
        () {
      final texto = mensajeFaltantes(
        sucursal: 'Ramada',
        fecha: DateTime(2026, 10, 5),
        faltantes: [
          // mínimo 23, quedan 3 → hacer 43
          _faltante('Flor Grande', 'Rojo', 3, 36.4),
          // mínimo 5, quedan 0 → hacer 10
          _faltante('Mariposa', 'Verde Esmeralda', 0, 8),
        ],
      );

      expect(
        texto,
        '*Huantex – Faltantes Ramada* (05/10/2026)\n'
        '\n'
        '• Flor Grande – Rojo: hacer *43* (quedan 3)\n'
        '• Mariposa – Verde Esmeralda: hacer *10* (quedan 0)\n'
        '\n'
        'Total a hacer: 53',
      );
    });

    test('respeta el orden recibido (el más urgente primero)', () {
      final texto = mensajeFaltantes(
        sucursal: 'Ramada',
        fecha: DateTime(2026, 10, 5),
        faltantes: [
          _faltante('B', 'x', 0, 8),
          _faltante('A', 'x', 0, 8),
        ],
      );

      expect(texto.indexOf('• B'), lessThan(texto.indexOf('• A')));
    });

    test('un stock con decimales se muestra con dos', () {
      final texto = mensajeFaltantes(
        sucursal: 'Ramada',
        fecha: DateTime(2026, 10, 5),
        faltantes: [_faltante('Flor', 'Rojo', 2.5, 8)],
      );

      expect(texto, contains('hacer *8* (quedan 2.50)'));
    });

    test('sin faltantes queda el título y el total en 0', () {
      final texto = mensajeFaltantes(
          sucursal: 'Ramada', fecha: DateTime(2026, 12, 31), faltantes: []);

      expect(texto,
          '*Huantex – Faltantes Ramada* (31/12/2026)\n\n\nTotal a hacer: 0');
    });
  });

  test('cantidadLegible: entero sin decimales, si no con dos', () {
    expect(cantidadLegible(12), '12');
    expect(cantidadLegible(0), '0');
    expect(cantidadLegible(2.5), '2.50');
    expect(cantidadLegible(0.3), '0.30');
  });
}
