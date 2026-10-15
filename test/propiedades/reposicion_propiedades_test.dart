import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';

import 'generadores.dart';

/// La regla de reposición contra un modelo en enteros (stock en centésimos):
/// mínimo = ⌈vendidas × 2,5 / 4⌉ = ⌈5·vendidas / 8⌉, falta si el stock no lo
/// supera y se pide hasta el doble.
void main() {
  propiedad('cada aplique+color coincide con el modelo en enteros', _entrada,
      (e) {
    final (vendidas, stock, _) = e;
    final r = Reposicion.de(_item(e), estimada: false);

    final minimo = vendidas == 0 ? 0 : (5 * vendidas + 7) ~/ 8;
    final falta = vendidas > 0 && stock.centesimos <= minimo * 100;
    final hacer = falta ? (2 * minimo * 100 - stock.centesimos + 99) ~/ 100 : 0;

    expect(r.minimo, minimo, reason: 'mínimo');
    expect(r.faltante, falta, reason: 'faltante');
    expect(r.hacer, hacer, reason: 'hacer');
    if (falta) {
      expect(stock.centesimos + r.hacer * 100,
          greaterThanOrEqualTo(2 * minimo * 100),
          reason: 'con lo pedido llega al doble del mínimo');
    }
  }, casos: 1000);

  propiedad(
      'más stock nunca pide más',
      any.combine2(_entrada, any.unidades(0, 60), (e, extra) => (e, extra)),
      (par) {
    final (e, extra) = par;
    final (vendidas, stock, otras) = e;
    final conMas = (vendidas, Decimal(stock.centesimos + extra.centesimos), otras);

    expect(Reposicion.de(_item(conMas), estimada: false).hacer,
        lessThanOrEqualTo(Reposicion.de(_item(e), estimada: false).hacer));
  });

  propiedad(
      'aplicar ordena sin perder nada: faltantes primero, el más urgente '
      'antes',
      any.listWithLengthInRange(0, 12, _entrada), (entradas) {
    final inventario = entradas.map(_item).toList();
    final items = ReglaReposicion.aplicar(inventario);

    expect(items.map((r) => r.item), unorderedEquals(inventario),
        reason: 'los mismos (por identidad), ni más ni menos');
    final faltantes = items.takeWhile((r) => r.faltante).length;
    expect(items.skip(faltantes).any((r) => r.faltante), isFalse,
        reason: 'ningún faltante después del primero que no falta');
    for (var i = 1; i < faltantes; i++) {
      expect(items[i - 1].semanasDeStock,
          lessThanOrEqualTo(items[i].semanasDeStock),
          reason: 'el que se termina antes va primero (posición $i)');
    }
  });

  propiedad('estima con las otras solo si la sucursal no vendió nada',
      any.listWithLengthInRange(1, 8, _entrada), (entradas) {
    final items = ReglaReposicion.aplicar(entradas.map(_item).toList());
    final sinVentasPropias = entradas.every((e) => e.$1 == 0);

    expect(items.every((r) => r.estimada == sinVentasPropias), isTrue);
    if (!sinVentasPropias) {
      // Lo de las otras no cuenta: sin venta propia no falta
      expect(
          items.where((r) => r.item.vendidas == 0).any((r) => r.faltante),
          isFalse);
    }
  });
}

/// (vendidas en la sucursal, stock, vendidas en las otras). Las ventas son
/// casi siempre unidades enteras; el stock a veces tiene decimales.
final _entrada = any.combine3(
  any.entero(0, 61),
  any.unidades(0, 60),
  any.entero(0, 61),
  (int vendidas, Decimal stock, int otras) => (vendidas, stock, otras),
);

StockConVentas _item((int, Decimal, int) e) => StockConVentas(
      apliqueId: 1,
      aplique: 'Flor',
      colorId: 1,
      color: 'Rojo',
      hex: '',
      stock: e.$2.valor,
      vendidas: e.$1.toDouble(),
      vendidasOtras: e.$3.toDouble(),
    );
