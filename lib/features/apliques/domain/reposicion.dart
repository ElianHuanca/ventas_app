import 'entities/stock_con_ventas.dart';

/// Cuándo reponer un aplique+color y cuánto pedirle al fabricante.
///
/// - Venta semanal: lo vendido en las últimas [semanasVentana] semanas.
/// - Mínimo: la venta de [semanasEntrega] + [semanasColchon]. El fabricante
///   tarda de 3 a 6 días hábiles (lunes, martes, jueves y viernes): en el
///   peor caso, 1,5 semanas. El colchón cubre las semanas que se vende más.
/// - Falta si el stock no supera el mínimo, y se pide hasta el doble.
/// - Lo que no se vendió en la ventana no se pide.
class ReglaReposicion {
  static const semanasVentana = 4;
  static const semanasEntrega = 1.5;
  static const semanasColchon = 1.0;

  const ReglaReposicion._();

  /// Aplica la regla al inventario de una sucursal: primero los faltantes,
  /// después el resto; cada parte en el orden de [porAplique].
  /// Si la sucursal no vendió nada en la ventana (recién empieza), estima con
  /// lo que venden las otras.
  static List<Reposicion> aplicar(List<StockConVentas> inventario) {
    final estimada = inventario.every((s) => s.vendidas == 0);
    return [for (final s in inventario) Reposicion.de(s, estimada: estimada)]
      ..sort(_faltantesPrimero);
  }

  static int _faltantesPrimero(Reposicion a, Reposicion b) {
    if (a.faltante != b.faltante) return a.faltante ? -1 : 1;
    return porAplique(a, b);
  }

  /// Como lo lee el fabricante: por aplique (A→Z) y, dentro de cada uno, de
  /// lo que más hay que hacer a lo que menos; a igual cantidad, por color.
  /// Sin distinguir mayúsculas.
  static int porAplique(Reposicion a, Reposicion b) {
    final porNombre =
        a.item.aplique.toLowerCase().compareTo(b.item.aplique.toLowerCase());
    if (porNombre != 0) return porNombre;
    final porCantidad = b.hacer.compareTo(a.hacer);
    if (porCantidad != 0) return porCantidad;
    return a.item.color.toLowerCase().compareTo(b.item.color.toLowerCase());
  }
}

class Reposicion {
  final StockConVentas item;

  /// La venta es la de las otras sucursales (esta no tiene historial).
  final bool estimada;
  final double porSemana;

  /// Con este stock o menos, falta.
  final int minimo;

  /// Cuánto pedirle al fabricante (0 si no falta).
  final int hacer;

  const Reposicion({
    required this.item,
    required this.estimada,
    required this.porSemana,
    required this.minimo,
    required this.hacer,
  });

  factory Reposicion.de(StockConVentas item, {required bool estimada}) {
    final vendidas = estimada ? item.vendidasOtras : item.vendidas;
    // Sin ventas el mínimo da 0 y no se pide nada (el stock nunca es
    // negativo: CHECK en la base)
    // vendidas × 2,5 / 4 en ese orden: con vendidas enteras da exacto en
    // binario (porSemana × 2,5 deja 5.000000001 y el ceil sube uno)
    final minimo = (vendidas *
            (ReglaReposicion.semanasEntrega + ReglaReposicion.semanasColchon) /
            ReglaReposicion.semanasVentana)
        .ceil();
    final hacer = item.stock <= minimo ? (2 * minimo - item.stock).ceil() : 0;
    return Reposicion(
      item: item,
      estimada: estimada,
      porSemana: vendidas / ReglaReposicion.semanasVentana,
      minimo: minimo,
      hacer: hacer,
    );
  }

  bool get faltante => hacer > 0;

  /// Para cuántas semanas alcanza el stock al ritmo de venta.
  double get semanasDeStock =>
      porSemana > 0 ? item.stock / porSemana : double.infinity;
}
