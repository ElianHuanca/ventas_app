// Driver de los macro-benchmarks: recibe lo que reportó
// benchmark/macro/app_benchmark.dart (comandos en su cabecera) y lo deja en
// build/benchmarks/macro/:
//
// - <clave>.timeline.json y <clave>.timeline_summary.json por cada traza
//   (`binding.traceAction`): la traza se abre en Perfetto o chrome://tracing.
//   El timeline del VM es un ring buffer (~9 MB): en las interacciones largas
//   (los scrolls) guarda solo el final. Las métricas completas son las de
//   FrameTiming, en resultados.json.
// - resultados.json: fluidez por flujo (FrameTiming de
//   `binding.watchPerformance`: build y raster promedio, p90, p99, peor y
//   frames perdidos) y latencias end-to-end (mínimo, mediana, promedio,
//   máximo).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

const _destino = 'build/benchmarks/macro';

/// Mismo valor que `sufijoFrames` en benchmark/macro/medicion.dart.
const _sufijoFrames = '.frames';

/// Presupuesto de un frame a 60 Hz (el mismo que usa FrameTimingSummarizer).
const _presupuestoUs = 16000;

Future<void> main() => integrationDriver(
      // Con las esperas de watchPerformance, en un emulador en debug la
      // corrida pasa los 20 minutos por defecto
      timeout: const Duration(minutes: 60),
      // Si un flujo falla, igual queda lo medido en los demás
      writeResponseOnFailure: true,
      responseDataCallback: _guardar,
    );

Future<void> _guardar(Map<String, dynamic>? datos) async {
  if (datos == null) {
    stderr.writeln('[macro] El benchmark no reportó datos.');
    return;
  }
  await Directory(_destino).create(recursive: true);

  final fluidez = <String, Map<String, num>>{};
  final timelines = <String, String>{};
  for (final MapEntry(:key, :value) in datos.entries) {
    if (value is! Map<String, dynamic>) continue;
    if (value.containsKey('traceEvents')) {
      timelines[key] = await _escribirTimeline(key, value);
    } else if (value.containsKey('frame_build_times')) {
      final flujo = key.endsWith(_sufijoFrames)
          ? key.substring(0, key.length - _sufijoFrames.length)
          : key;
      fluidez[flujo] = _fluidez(value);
    }
  }
  final latencias = <String, Map<String, Object>>{
    for (final MapEntry(:key, :value)
        in ((datos['latencias'] as Map<String, dynamic>?) ?? {}).entries)
      key: _estadisticas((value as List).cast<num>()),
  };

  final entorno = datos['entorno'] as Map<String, dynamic>?;
  final resultados = {
    'fecha': DateTime.now().toIso8601String(),
    'entorno': entorno,
    'presupuesto_frame_ms': _presupuestoUs / 1000,
    'fluidez': fluidez,
    'latencias_ms': latencias,
    'timelines': timelines,
    if (datos['errores'] != null) 'errores': datos['errores'],
  };
  final archivo = File('$_destino/resultados.json');
  await archivo
      .writeAsString(const JsonEncoder.withIndent('  ').convert(resultados));

  _imprimir(entorno, fluidez, latencias);
  stdout.writeln('[macro] Resultados en ${archivo.path}');

  // integration_test no cuenta las fallas de setUpAll/tearDownAll y diría
  // "All tests passed": el target las reporta aparte
  final errores = (datos['errores'] as List?) ?? const [];
  if (errores.isNotEmpty) {
    stderr.writeln('[macro] Falló la preparación o el cierre:');
    for (final error in errores) {
      stderr.writeln('  $error');
    }
    exit(1);
  }
}

/// Escribe la traza y su resumen. Devuelve el archivo de resumen o, si la
/// traza no tiene frames que resumir, por qué no lo hay.
Future<String> _escribirTimeline(
    String clave, Map<String, dynamic> json) async {
  final resumen =
      driver.TimelineSummary.summarize(driver.Timeline.fromJson(json));
  try {
    await resumen.writeTimelineToFile(clave,
        destinationDirectory: _destino, pretty: true, includeSummary: true);
    return '$clave.timeline_summary.json';
  } catch (e) {
    // La traza ya quedó escrita; falló solo el resumen
    return 'sin resumen ($clave.timeline.json): $e';
  }
}

Map<String, num> _fluidez(Map<String, dynamic> resumen) {
  num ms(String clave) => _redondear(resumen[clave] as num);
  int cantidad(String clave) => resumen[clave] as int;
  final build = (resumen['frame_build_times'] as List).cast<int>();
  final raster = (resumen['frame_rasterizer_times'] as List).cast<int>();
  var perdidos = 0;
  for (var i = 0; i < build.length && i < raster.length; i++) {
    if (build[i] > _presupuestoUs || raster[i] > _presupuestoUs) perdidos++;
  }
  final frames = cantidad('frame_count');
  return {
    'frames': frames,
    'build_promedio_ms': ms('average_frame_build_time_millis'),
    'build_p90_ms': ms('90th_percentile_frame_build_time_millis'),
    'build_p99_ms': ms('99th_percentile_frame_build_time_millis'),
    'build_peor_ms': ms('worst_frame_build_time_millis'),
    'raster_promedio_ms': ms('average_frame_rasterizer_time_millis'),
    'raster_p90_ms': ms('90th_percentile_frame_rasterizer_time_millis'),
    'raster_p99_ms': ms('99th_percentile_frame_rasterizer_time_millis'),
    'raster_peor_ms': ms('worst_frame_rasterizer_time_millis'),
    // Frames que se pasaron del presupuesto en build o en raster
    'frames_perdidos': perdidos,
    'frames_perdidos_pct':
        frames == 0 ? 0 : _redondear(100 * perdidos / frames),
    'build_frames_perdidos': cantidad('missed_frame_build_budget_count'),
    'raster_frames_perdidos': cantidad('missed_frame_rasterizer_budget_count'),
    'gc_nueva_generacion': cantidad('new_gen_gc_count'),
    'gc_vieja_generacion': cantidad('old_gen_gc_count'),
  };
}

Map<String, Object> _estadisticas(List<num> muestras) {
  final orden = [...muestras]..sort();
  final n = orden.length;
  final mediana =
      n.isOdd ? orden[n ~/ 2] : (orden[n ~/ 2 - 1] + orden[n ~/ 2]) / 2;
  return {
    'muestras': n,
    'min': _redondear(orden.first),
    'mediana': _redondear(mediana),
    'promedio': _redondear(orden.reduce((a, b) => a + b) / n),
    'max': _redondear(orden.last),
    'valores': [for (final m in muestras) _redondear(m)],
  };
}

double _redondear(num valor) => double.parse(valor.toStringAsFixed(1));

void _imprimir(
  Map<String, dynamic>? entorno,
  Map<String, Map<String, num>> fluidez,
  Map<String, Map<String, Object>> latencias,
) {
  final out = stdout;
  out.writeln('\n[macro] Entorno: ${jsonEncode(entorno)}');
  if (entorno?['modo'] != 'profile') {
    out.writeln('[macro] OJO: corrida en ${entorno?['modo']}; los números solo '
        'sirven en --profile en un celular físico.');
  }
  String col(Object? v, int ancho) => '$v'.padLeft(ancho);

  out.writeln('\nFluidez (ms)               frames  build prom/p90/p99   '
      'raster prom/p90/p99  perdidos');
  for (final MapEntry(:key, :value) in fluidez.entries) {
    out.writeln('${key.padRight(26)}${col(value['frames'], 6)}  '
        '${col(value['build_promedio_ms'], 5)}/${col(value['build_p90_ms'], 5)}'
        '/${col(value['build_p99_ms'], 5)}  '
        '${col(value['raster_promedio_ms'], 5)}/${col(value['raster_p90_ms'], 5)}'
        '/${col(value['raster_p99_ms'], 5)}  '
        '${col(value['frames_perdidos'], 4)} (${value['frames_perdidos_pct']}%)');
  }

  out.writeln('\nLatencia (ms)              mediana     min     max   n');
  for (final MapEntry(:key, :value) in latencias.entries) {
    out.writeln('${key.padRight(26)}${col(value['mediana'], 7)} '
        '${col(value['min'], 7)} ${col(value['max'], 7)} '
        '${col(value['muestras'], 3)}');
  }
}
