// ignore_for_file: file_names

class DetalleVenta {
  final int? id;
  final String? nombre;
  final double precio;
  final double cantidad;
  final double? total;
  final double? ganancias;
  final int idtelas;

  const DetalleVenta({
    this.id,
    this.nombre,
    required this.precio,
    required this.cantidad,
    this.total,
    required this.idtelas,
    this.ganancias,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'precio': precio,
      'cantidad': cantidad,
      'total': total,
      'idtelas': idtelas,
      'ganancias': ganancias,
    };
  }
}
