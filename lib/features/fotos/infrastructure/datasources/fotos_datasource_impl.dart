import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:textiles_app/config/supabase/supabase_config.dart';

import '../../domain/domain.dart';

/// Fotos en el bucket público `fotos` de Storage (migración
/// 20261021000000_fotos_de_productos.sql) y una fila por foto en
/// tela_fotos / aplique_fotos con su URL pública. Quitar es baja lógica:
/// el archivo queda en el bucket.
class FotosDatasourceImpl implements FotosDatasource {
  static const bucket = 'fotos';

  final _db = SupabaseConfig.client;
  final _random = Random.secure();

  @override
  Future<String> getNombre(ProductoConFotos producto, int id) async {
    final row = await _db
        .from(producto.productos)
        .select('nombre')
        .eq('id', id)
        .single();
    return row['nombre'] as String? ?? '';
  }

  @override
  Future<List<Foto>> getFotos(ProductoConFotos producto, int id) async {
    final list = await _db
        .from(producto.tabla)
        .select('id, url')
        .eq(producto.columna, id)
        .eq('activo', true)
        // postgrest-dart ordena descendente por defecto: la primera subida
        // es la principal (la de la web), así que va explícito
        .order('id', ascending: true);
    return list.map(fotoDesdeJson).toList();
  }

  @override
  Future<Foto> subirFoto(
      ProductoConFotos producto, int id, FotoElegida foto) async {
    final ruta = rutaDeFoto(producto, id, foto.extension,
        DateTime.now().millisecondsSinceEpoch, _random.nextInt(1 << 32));
    final archivos = _db.storage.from(bucket);
    await archivos.uploadBinary(
      ruta,
      Uint8List.fromList(foto.bytes),
      fileOptions: FileOptions(contentType: tipoMime(foto.extension)),
    );
    final row = await _db
        .from(producto.tabla)
        .insert({producto.columna: id, 'url': archivos.getPublicUrl(ruta)})
        .select('id, url')
        .single();
    return fotoDesdeJson(row);
  }

  @override
  Future<void> quitarFoto(ProductoConFotos producto, int idfoto) async {
    await _db.from(producto.tabla).update({'activo': false}).eq('id', idfoto);
  }
}

Foto fotoDesdeJson(Map<String, dynamic> json) =>
    Foto(id: json['id'] as int, url: json['url'] as String);

/// `telas/12/1760000000000_3f2a1b9c.jpg`: una carpeta por producto y un
/// nombre que no se repite (el bucket no pisa archivos).
String rutaDeFoto(ProductoConFotos producto, int id, String extension,
        int milisegundos, int aleatorio) =>
    '${producto.productos}/$id/${milisegundos}_'
    '${aleatorio.toRadixString(16).padLeft(8, '0')}.$extension';

/// El bucket solo acepta estos tres (allowed_mime_types).
String tipoMime(String extension) => switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
