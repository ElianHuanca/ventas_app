class TelaSucursal {
  final int idtela;
  final String nombre;
  final bool disponible;

  const TelaSucursal({
    required this.idtela,
    required this.nombre,
    required this.disponible,
  });

  TelaSucursal copyWith({bool? disponible}) => TelaSucursal(
        idtela: idtela,
        nombre: nombre,
        disponible: disponible ?? this.disponible,
      );
}
