// Copia los vectores de prueba compartidos al port Android, o verifica que la
// copia esté al día. Sin dependencias.
//
// La fuente de verdad son los `test/vectores/*.json` de este repo (casos
// { "nombre", "entrada", "esperado" } que recorren los tests de cada port).
// Android los lee de `app/src/test/resources/vectores/` en su repo: esa
// carpeta es un espejo y no se edita a mano.
//
//   dart run tool/sincronizar_vectores.dart                 # copia a ../ventas_app_android
//   dart run tool/sincronizar_vectores.dart <ruta_android>   # copia a otro checkout
//   dart run tool/sincronizar_vectores.dart --verificar [<ruta_android>]
//
// Copiar escribe cada JSON con fin de línea LF y borra de la carpeta destino
// los .json que ya no existen acá. Con --verificar no escribe nada: compara
// (ignorando CRLF/LF, que git puede cambiar al hacer checkout en Windows) y
// sale con código 1 si falta, sobra o difiere alguna copia.
//
// iOS (`../ventas_app_ios`, Swift) no tiene copia todavía: ver "Vectores de
// prueba compartidos" en CLAUDE.md.
import 'dart:io';

const _origen = 'test/vectores';
const _destinoRelativo = 'app/src/test/resources/vectores';
const _uso =
    'Uso: dart run tool/sincronizar_vectores.dart [--verificar] [<ruta_android>]';

void main(List<String> argumentos) {
  var verificar = false;
  String? ruta;
  for (final a in argumentos) {
    if (a == '--verificar') {
      verificar = true;
    } else if (a == '-h' || a == '--help') {
      stdout.writeln(_uso);
      return;
    } else if (a.startsWith('-') || ruta != null) {
      stderr
        ..writeln('sincronizar_vectores: argumento inesperado "$a"')
        ..writeln(_uso);
      exitCode = 2;
      return;
    } else {
      ruta = a;
    }
  }
  ruta ??= '../ventas_app_android';

  final android = Directory(ruta);
  if (!File('${android.path}/settings.gradle.kts').existsSync()) {
    stderr.writeln('sincronizar_vectores: "$ruta" no parece el repo de Android '
        '(no tiene settings.gradle.kts)');
    exitCode = 2;
    return;
  }

  final fuentes = _jsonEn(Directory(_origen));
  if (fuentes.isEmpty) {
    stderr.writeln('sincronizar_vectores: no hay vectores en $_origen '
        '(correr desde la raíz de ventas_app)');
    exitCode = 2;
    return;
  }
  final destino = Directory('${android.path}/$_destinoRelativo');
  final copias = destino.existsSync() ? _jsonEn(destino) : <String, File>{};

  final problemas = <String>[];
  for (final MapEntry(key: nombre, value: fuente) in fuentes.entries) {
    final contenido = _lf(fuente.readAsStringSync());
    final copia = copias[nombre];
    final igual = copia != null && _lf(copia.readAsStringSync()) == contenido;
    if (igual) continue;
    if (verificar) {
      problemas.add(copia == null ? 'falta $nombre' : 'difiere $nombre');
    } else {
      destino.createSync(recursive: true);
      File('${destino.path}/$nombre').writeAsStringSync(contenido);
      stdout.writeln('${copia == null ? 'copiado' : 'actualizado'} $nombre');
    }
  }
  for (final MapEntry(key: nombre, value: copia) in copias.entries) {
    if (fuentes.containsKey(nombre)) continue;
    if (verificar) {
      problemas.add('sobra $nombre (ya no está en $_origen)');
    } else {
      copia.deleteSync();
      stdout.writeln('borrado $nombre');
    }
  }

  if (verificar) {
    if (problemas.isEmpty) {
      stdout.writeln('Los ${fuentes.length} vectores de ${destino.path} '
          'están al día.');
    } else {
      stderr
        ..writeln('Las copias de ${destino.path} no están al día:')
        ..writeAll(problemas.map((p) => '  $p\n'))
        ..writeln('Sincronizar con: dart run tool/sincronizar_vectores.dart '
            '$ruta');
      exitCode = 1;
    }
  } else {
    stdout.writeln('${fuentes.length} vectores sincronizados en '
        '${destino.path}.');
  }
}

/// Los .json de [carpeta] (sin subcarpetas), por nombre de archivo.
Map<String, File> _jsonEn(Directory carpeta) {
  if (!carpeta.existsSync()) return {};
  final archivos = carpeta
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return {for (final f in archivos) f.uri.pathSegments.last: f};
}

String _lf(String texto) => texto.replaceAll('\r\n', '\n');
