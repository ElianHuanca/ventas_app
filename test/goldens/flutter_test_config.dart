// Configuración de los tests de captura (golden) de test/goldens/.
//
// flutter_test dibuja el texto con la fuente Ahem (cada letra es un cuadrado
// negro) y los íconos como cajas. Para que las capturas se lean como la app
// real, acá se cargan Roboto y MaterialIcons desde el SDK de Flutter.
// Solo aplica a los tests de esta carpeta: los de widget de test/features/
// siguen con Ahem y sus medidas no cambian.
//
// Las capturas se generaron en Windows: el antialiasing del texto cambia entre
// sistemas operativos, así que en otro SO hay que regenerarlas
// (`flutter test test/goldens --update-goldens`) o excluirlas
// (`flutter test --exclude-tags golden`).
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _cargarFuentes();
  await testMain();
}

Future<void> _cargarFuentes() async {
  final carpeta = Directory(
    '${_raizDeFlutter()}/bin/cache/artifacts/material_fonts',
  );
  if (!carpeta.existsSync()) {
    throw StateError('No se encontraron las fuentes del SDK en ${carpeta.path}');
  }
  // En Windows los archivos están en minúsculas y en otros SO no: se buscan
  // sin distinguir mayúsculas.
  final archivos = {
    for (final f in carpeta.listSync().whereType<File>())
      f.uri.pathSegments.last.toLowerCase(): f,
  };
  ByteData leer(String nombre) {
    final archivo = archivos[nombre];
    if (archivo == null) throw StateError('Falta la fuente $nombre');
    return ByteData.sublistView(archivo.readAsBytesSync());
  }

  // Un TextStyle sin fontFamily sigue saliendo con la fuente de prueba (el
  // engine no deja reemplazarla): golden_helpers.dart le pone Roboto a los
  // estilos de AppTheme que no la heredan.
  final roboto = FontLoader('Roboto');
  for (final nombre in archivos.keys.where(
    (n) => n.startsWith('roboto-') && n.endsWith('.ttf'),
  )) {
    roboto.addFont(Future.value(leer(nombre)));
  }
  await roboto.load();

  final iconos = FontLoader('MaterialIcons')
    ..addFont(Future.value(leer('materialicons-regular.otf')));
  await iconos.load();
}

/// FLUTTER_ROOT si el tool la exporta; si no, se deduce del flutter_tester
/// (`<raíz>/bin/cache/artifacts/engine/<plataforma>/flutter_tester`).
String _raizDeFlutter() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    dir = dir.parent;
  }
  return dir.path;
}
