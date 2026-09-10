class ColorItem {
  final int id;
  final String nombre;
  final String hex;

  /// true cuando el color está vinculado al producto consultado
  /// (tela_colores / aplique_colores con activo = true).
  final bool vinculado;

  const ColorItem({
    required this.id,
    required this.nombre,
    this.hex = '',
    this.vinculado = false,
  });
}
