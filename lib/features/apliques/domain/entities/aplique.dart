class Aplique {
  final int id;
  final String nombre;
  final double costoFabricacion;
  final String tamanio;
  final bool activo;

  Aplique({
    required this.id,
    required this.nombre,
    this.costoFabricacion = 0,
    this.tamanio = '',
    this.activo = true,
  });

  // Constructor para crear un aplique vacío
  factory Aplique.empty() {
    return Aplique(
      id: 0,
      nombre: '',
      costoFabricacion: 0,
      tamanio: '',
    );
  }
}
