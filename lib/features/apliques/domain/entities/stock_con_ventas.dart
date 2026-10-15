/// Una fila del inventario de una sucursal (aplique+color) con lo vendido en
/// las últimas semanas: lo que necesita la regla de reposición.
class StockConVentas {
  final int apliqueId;
  final String aplique;
  final int colorId;
  final String color;
  final String hex;
  final double stock;

  /// Unidades vendidas en la sucursal en la ventana.
  final double vendidas;

  /// Promedio vendido en las otras sucursales que venden: estima la venta de
  /// una sucursal sin historial propio.
  final double vendidasOtras;

  const StockConVentas({
    required this.apliqueId,
    required this.aplique,
    required this.colorId,
    required this.color,
    required this.hex,
    required this.stock,
    required this.vendidas,
    this.vendidasOtras = 0,
  });
}
