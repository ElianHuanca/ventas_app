/// Una foto activa de una tela o un aplique (`tela_fotos` / `aplique_fotos`).
/// [url] es la URL pública del archivo en el bucket `fotos` de Storage.
class Foto {
  final int id;
  final String url;

  const Foto({required this.id, required this.url});

  @override
  bool operator ==(Object other) =>
      other is Foto && other.id == id && other.url == url;

  @override
  int get hashCode => Object.hash(id, url);

  @override
  String toString() => 'Foto($id, $url)';
}

/// Qué producto tiene las fotos: decide la tabla, la columna que lo
/// referencia y la carpeta del bucket.
enum ProductoConFotos {
  tela(tabla: 'tela_fotos', columna: 'idtela', productos: 'telas'),
  aplique(tabla: 'aplique_fotos', columna: 'idaplique', productos: 'apliques');

  const ProductoConFotos({
    required this.tabla,
    required this.columna,
    required this.productos,
  });

  /// Tabla de las fotos.
  final String tabla;

  /// Columna de [tabla] con el id del producto.
  final String columna;

  /// Tabla del producto (para el nombre) y carpeta del bucket.
  final String productos;
}

/// Una imagen elegida en el celular, lista para subir.
class FotoElegida {
  final List<int> bytes;

  /// `jpg`, `png` o `webp` (lo que acepta el bucket).
  final String extension;

  const FotoElegida({required this.bytes, required this.extension});
}
