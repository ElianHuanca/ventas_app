import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// PNG chico de un solo color, para dibujar "fotos" sin red en los tests y
/// las capturas (Image.network en flutter_test siempre falla).
Uint8List pngDeColor(int r, int g, int b) {
  final imagen = img.Image(width: 8, height: 8)
    ..clear(img.ColorRgb8(r, g, b));
  return img.encodePng(imagen);
}

final _porUrl = <String, ImageProvider>{};

/// Una imagen en memoria distinta por URL (el color sale de la URL), para
/// pasarle a FotosScreen(imagen:). La misma instancia para la misma URL: si
/// no, cada rebuild la vuelve a decodificar.
ImageProvider imagenDePrueba(String url) => _porUrl.putIfAbsent(url, () {
      final h = url.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xffffff);
      return MemoryImage(pngDeColor(h & 0xff, (h >> 8) & 0xff, h >> 16));
    });

/// Al terminar el test: deja terminar de decodificar las imágenes (fuera
/// del reloj falso), desmonta y vacía la caché. La caché retiene un handle
/// por imagen mostrada hasta que el binding la vacía al EMPEZAR el test
/// siguiente, y un handle a medio decodificar no se libera con clear(): en
/// el último test del archivo leak_tracker lo cuenta como fuga.
void liberarImagenesAlTerminar(WidgetTester tester) {
  addTearDown(() async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpWidget(const SizedBox());
    imageCache
      ..clear()
      ..clearLiveImages();
  });
}
