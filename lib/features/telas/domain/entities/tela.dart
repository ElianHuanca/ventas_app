class Tela {
  final int id;
  final String nombre;
  final double? precxmen;
  final double? precxmay;
  final double? precxrollo;
  final double? precxcompra;

  Tela({
    this.precxmen,
    this.precxmay,
    this.precxrollo,
    this.precxcompra,
    required this.id,
    required this.nombre,
  });

  // Constructor para crear una tela vacía
  factory Tela.empty() {
    return Tela(
      id: 0,
      nombre: '',
      precxmen: 0,
      precxmay: 0,
      precxrollo: 0,
      precxcompra: 0,
    );
  }
}
