import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/fotos/fotos.dart';

void main() {
  test('fotoDesdeJson lee id y url', () {
    expect(fotoDesdeJson({'id': 3, 'url': 'https://x/3.jpg'}),
        const Foto(id: 3, url: 'https://x/3.jpg'));
  });

  test('rutaDeFoto: carpeta por producto y nombre que no se repite', () {
    expect(rutaDeFoto(ProductoConFotos.tela, 12, 'jpg', 1760000000000, 0xab),
        'telas/12/1760000000000_000000ab.jpg');
    expect(rutaDeFoto(ProductoConFotos.aplique, 4, 'png', 5, 0xdeadbeef),
        'apliques/4/5_deadbeef.png');
  });

  test('tipoMime: los tres que acepta el bucket', () {
    expect(tipoMime('jpg'), 'image/jpeg');
    expect(tipoMime('png'), 'image/png');
    expect(tipoMime('webp'), 'image/webp');
  });

  test('extensionDeFoto: normaliza y lo desconocido se sube como jpg', () {
    expect(extensionDeFoto('IMG_1.PNG'), 'png');
    expect(extensionDeFoto('a.webp'), 'webp');
    expect(extensionDeFoto('foto.jpeg'), 'jpg');
    expect(extensionDeFoto('foto.heic'), 'jpg');
    expect(extensionDeFoto('sin_extension'), 'jpg');
  });

  test('cada producto apunta a su tabla, columna y carpeta', () {
    expect(ProductoConFotos.tela.tabla, 'tela_fotos');
    expect(ProductoConFotos.tela.columna, 'idtela');
    expect(ProductoConFotos.tela.productos, 'telas');
    expect(ProductoConFotos.aplique.tabla, 'aplique_fotos');
    expect(ProductoConFotos.aplique.columna, 'idaplique');
    expect(ProductoConFotos.aplique.productos, 'apliques');
  });
}
