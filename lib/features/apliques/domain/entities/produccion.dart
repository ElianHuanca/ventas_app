class Produccion {
  final int id;
  final String fecha;
  final String sucursalNombre;
  final String apliqueNombre;
  final String colorNombre;
  final String hex;
  final double cantidad;

  const Produccion({
    required this.id,
    required this.fecha,
    required this.sucursalNombre,
    required this.apliqueNombre,
    required this.colorNombre,
    this.hex = '',
    required this.cantidad,
  });
}
