// Resumen de cobertura de `flutter test --coverage`, sin dependencias.
//
// Lee el lcov que deja flutter test (coverage/lcov.info), descarta los
// archivos generados, imprime el porcentaje de líneas cubiertas por carpeta y
// el total, y sale con código 1 si el total queda por debajo de --minimo. Lo
// usa el job `analisis-y-tests` de .github/workflows/ci.yml.
//
//   flutter test --exclude-tags golden --coverage
//   dart run tool/cobertura.dart --minimo 80
//
// Opciones:
//   --lcov <ruta>         lcov a leer (por defecto coverage/lcov.info)
//   --minimo <n>          porcentaje total mínimo, 0–100 (por defecto 0: solo informa)
//   --profundidad <n>     segmentos de ruta que forman la "carpeta" (por defecto 3:
//                         lib/features/apliques, lib/config/router…)
//
// Ojo: flutter test solo reporta los archivos que algún test importó. Un
// archivo de lib/ que ningún test carga no aparece en el lcov (no baja el
// total): el script los lista aparte como "sin ningún test".
//
// En GitHub Actions (GITHUB_STEP_SUMMARY definida) agrega también la tabla al
// resumen de la corrida.
import 'dart:io';

/// Sufijos y rutas de archivos generados: no se cuentan.
const _generados = [
  '.g.dart',
  '.freezed.dart',
  '.mocks.dart',
  '.gr.dart',
  '.config.dart',
  'generated_plugin_registrant.dart',
  '/generated/',
  '/l10n/app_localizations',
];

Future<void> main(List<String> argumentos) async {
  final Opciones opciones;
  try {
    opciones = Opciones.leer(argumentos);
  } on FormatException catch (e) {
    stderr
      ..writeln('cobertura: ${e.message}')
      ..writeln(
          'Uso: dart run tool/cobertura.dart [--lcov <ruta>] [--minimo <n>] [--profundidad <n>]');
    exitCode = 2;
    return;
  }

  final lcov = File(opciones.lcov);
  if (!lcov.existsSync()) {
    stderr.writeln('cobertura: no existe ${opciones.lcov} '
        '(correr antes `flutter test --coverage`).');
    exitCode = 2;
    return;
  }

  final archivos = leerLcov(lcov.readAsLinesSync())
    ..removeWhere((ruta, _) => esGenerado(ruta));
  if (archivos.isEmpty) {
    stderr.writeln('cobertura: ${opciones.lcov} no tiene archivos de lib/.');
    exitCode = 2;
    return;
  }

  final carpetas = <String, Conteo>{};
  final total = Conteo();
  for (final MapEntry(key: ruta, value: lineas) in archivos.entries) {
    final conteo = Conteo.de(lineas);
    carpetas
        .putIfAbsent(carpeta(ruta, opciones.profundidad), Conteo.new)
        .sumar(conteo);
    total.sumar(conteo);
  }

  final sinTests = archivosSinTests(archivos.keys.toSet());
  final ok = total.porcentaje >= opciones.minimo;

  stdout.write(tablaTexto(carpetas, total, opciones, sinTests, ok));
  final resumen = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (resumen != null && resumen.isNotEmpty) {
    File(resumen).writeAsStringSync(
      tablaMarkdown(carpetas, total, opciones, sinTests, ok),
      mode: FileMode.append,
    );
  }

  if (!ok) {
    stderr.writeln('cobertura: el total (${_pct(total.porcentaje)} %) quedó '
        'por debajo del mínimo (${_pct(opciones.minimo)} %).');
    exitCode = 1;
  }
}

class Opciones {
  Opciones({
    this.lcov = 'coverage/lcov.info',
    this.minimo = 0,
    this.profundidad = 3,
  });

  /// Acepta `--opcion valor` y `--opcion=valor`.
  factory Opciones.leer(List<String> argumentos) {
    final valores = <String, String>{};
    for (var i = 0; i < argumentos.length; i++) {
      final arg = argumentos[i];
      if (!arg.startsWith('--')) {
        throw FormatException('argumento inesperado "$arg"');
      }
      final igual = arg.indexOf('=');
      if (igual != -1) {
        valores[arg.substring(2, igual)] = arg.substring(igual + 1);
      } else if (i + 1 < argumentos.length) {
        valores[arg.substring(2)] = argumentos[++i];
      } else {
        throw FormatException('falta el valor de $arg');
      }
    }
    final desconocidas =
        valores.keys.toSet().difference({'lcov', 'minimo', 'profundidad'});
    if (desconocidas.isNotEmpty) {
      throw FormatException('opción desconocida --${desconocidas.first}');
    }

    final minimo = double.tryParse(valores['minimo'] ?? '0');
    if (minimo == null || minimo < 0 || minimo > 100) {
      throw FormatException(
          '--minimo tiene que ser un número entre 0 y 100 (vino "${valores['minimo']}")');
    }
    final profundidad = int.tryParse(valores['profundidad'] ?? '3');
    if (profundidad == null || profundidad < 1) {
      throw FormatException(
          '--profundidad tiene que ser un entero ≥ 1 (vino "${valores['profundidad']}")');
    }
    return Opciones(
      lcov: valores['lcov'] ?? 'coverage/lcov.info',
      minimo: minimo,
      profundidad: profundidad,
    );
  }

  final String lcov;
  final double minimo;
  final int profundidad;
}

/// Líneas ejecutables y cubiertas.
class Conteo {
  Conteo();

  /// [lineas]: número de línea → veces que se ejecutó.
  Conteo.de(Map<int, int> lineas)
      : total = lineas.length,
        cubiertas = lineas.values.where((veces) => veces > 0).length;

  int total = 0;
  int cubiertas = 0;

  void sumar(Conteo otro) {
    total += otro.total;
    cubiertas += otro.cubiertas;
  }

  /// Un archivo sin líneas ejecutables cuenta como cubierto.
  double get porcentaje => total == 0 ? 100 : cubiertas * 100 / total;
}

/// Archivo (ruta relativa con `/`) → número de línea → veces que se ejecutó.
///
/// Se cuentan las líneas `DA:` (no los `LF`/`LH` del registro) para poder
/// unir registros repetidos del mismo archivo: una línea está cubierta si
/// algún registro la ejecutó.
Map<String, Map<int, int>> leerLcov(List<String> lineas) {
  final archivos = <String, Map<int, int>>{};
  Map<int, int>? actual;
  for (final cruda in lineas) {
    final linea = cruda.trim();
    if (linea.startsWith('SF:')) {
      actual = archivos.putIfAbsent(
          normalizarRuta(linea.substring(3)), () => <int, int>{});
    } else if (linea.startsWith('DA:') && actual != null) {
      final partes = linea.substring(3).split(',');
      if (partes.length < 2) continue;
      final numero = int.tryParse(partes[0]);
      final veces = int.tryParse(partes[1]);
      if (numero == null || veces == null) continue;
      actual[numero] = (actual[numero] ?? 0) + veces;
    } else if (linea == 'end_of_record') {
      actual = null;
    }
  }
  return archivos;
}

/// Ruta relativa a la raíz del paquete, con `/` (en Windows el lcov puede
/// traer `\` o la ruta absoluta).
String normalizarRuta(String ruta) {
  var r = ruta.replaceAll(r'\', '/');
  final lib = r.indexOf('/lib/');
  if (!r.startsWith('lib/') && lib != -1) r = r.substring(lib + 1);
  return r;
}

bool esGenerado(String ruta) => _generados.any(ruta.contains);

/// Los primeros [profundidad] segmentos de la carpeta del archivo:
/// `lib/features/apliques/domain/x.dart` → `lib/features/apliques`.
String carpeta(String ruta, int profundidad) {
  final segmentos = ruta.split('/')..removeLast();
  if (segmentos.isEmpty) return '.';
  return segmentos.take(profundidad).join('/');
}

/// Archivos de lib/ con código que no aparecen en el lcov: ningún test los
/// importó. Los que no tienen líneas ejecutables (barrels de `export`, repos y
/// datasources abstractos, excepciones vacías) tampoco aparecen en el lcov
/// aunque se importen, así que no se listan.
List<String> archivosSinTests(Set<String> enLcov) {
  final lib = Directory('lib');
  if (!lib.existsSync()) return const [];
  return [
    for (final f in lib.listSync(recursive: true).whereType<File>())
      if (f.path.endsWith('.dart') &&
          !enLcov.contains(normalizarRuta(f.path)) &&
          !esGenerado(normalizarRuta(f.path)) &&
          tieneCodigo(f.readAsStringSync()))
        normalizarRuta(f.path),
  ]..sort();
}

/// Aproximación (sin parser): hay un cuerpo de función, una flecha o un
/// `return` fuera de los comentarios. Las firmas abstractas (`Future<X> f();`)
/// y los `export` no cuentan.
bool tieneCodigo(String fuente) {
  final sinComentarios = fuente
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');
  return RegExp(r'=>|\)\s*(async\s*\*?\s*)?\{|\breturn\b')
      .hasMatch(sinComentarios);
}

String _pct(double valor) => valor.toStringAsFixed(1);

String tablaTexto(Map<String, Conteo> carpetas, Conteo total, Opciones opciones,
    List<String> sinTests, bool ok) {
  final ancho = [
    'TOTAL'.length,
    ...carpetas.keys.map((c) => c.length),
  ].reduce((a, b) => a > b ? a : b);
  final b = StringBuffer()
    ..writeln('Cobertura de líneas (${opciones.lcov}, sin archivos generados)')
    ..writeln()
    ..writeln('${'carpeta'.padRight(ancho)}  ${'líneas'.padLeft(7)}  '
        '${'cubiertas'.padLeft(9)}  ${'%'.padLeft(6)}');
  for (final c in carpetas.keys.toList()..sort()) {
    final conteo = carpetas[c]!;
    b.writeln('${c.padRight(ancho)}  ${'${conteo.total}'.padLeft(7)}  '
        '${'${conteo.cubiertas}'.padLeft(9)}  '
        '${_pct(conteo.porcentaje).padLeft(6)}');
  }
  b
    ..writeln('${'-' * ancho}  ${'-' * 7}  ${'-' * 9}  ${'-' * 6}')
    ..writeln('${'TOTAL'.padRight(ancho)}  ${'${total.total}'.padLeft(7)}  '
        '${'${total.cubiertas}'.padLeft(9)}  '
        '${_pct(total.porcentaje).padLeft(6)}')
    ..writeln()
    ..writeln(
        'Mínimo: ${_pct(opciones.minimo)} % → ${ok ? 'OK' : 'NO ALCANZA'}');
  if (sinTests.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Archivos de lib/ sin ningún test (no están en el lcov ni '
          'cuentan en el total):');
    for (final r in sinTests) {
      b.writeln('  $r');
    }
  }
  return b.toString();
}

String tablaMarkdown(Map<String, Conteo> carpetas, Conteo total,
    Opciones opciones, List<String> sinTests, bool ok) {
  final b = StringBuffer()
    ..writeln('### Cobertura de líneas: ${_pct(total.porcentaje)} % '
        '(mínimo ${_pct(opciones.minimo)} %): ${ok ? 'OK' : 'NO ALCANZA'}')
    ..writeln()
    ..writeln('| Carpeta | Líneas | Cubiertas | % |')
    ..writeln('|---|---:|---:|---:|');
  for (final c in carpetas.keys.toList()..sort()) {
    final conteo = carpetas[c]!;
    b.writeln('| `$c` | ${conteo.total} | ${conteo.cubiertas} | '
        '${_pct(conteo.porcentaje)} |');
  }
  b
    ..writeln('| **Total** | **${total.total}** | **${total.cubiertas}** | '
        '**${_pct(total.porcentaje)}** |')
    ..writeln();
  if (sinTests.isNotEmpty) {
    b.writeln('Sin ningún test (fuera del total): '
        '${sinTests.map((r) => '`$r`').join(', ')}');
    b.writeln();
  }
  return b.toString();
}
