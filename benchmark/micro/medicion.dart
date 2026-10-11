// Helpers de los micro-benchmarks (benchmark/micro/).
//
// Corren con flutter_test (JIT, con asserts): los números no son los de un
// release, pero sirven para comparar una corrida con otra y para detectar una
// regresión grosera. Cada benchmark tiene un presupuesto holgado (~10x lo
// medido) y falla si lo excede.
//
//   flutter test benchmark/micro
//   flutter test benchmark/micro --dart-define=BENCH_MS=3000   # más precisión
//
// Los resultados quedan en build/benchmarks/micro/<grupo>.json.
import 'dart:convert';
import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tiempo mínimo de medición de cada benchmark (después de 100 ms de warmup).
const _duracionMs = int.fromEnvironment('BENCH_MS', defaultValue: 1000);

final _resultados = <String, Map<String, Object>>{};

/// Agrupa benchmarks y al terminar guarda sus resultados en
/// `build/benchmarks/micro/<nombre>.json`.
void grupoBenchmark(String nombre, void Function() cuerpo) {
  group(nombre, () {
    tearDownAll(() {
      final archivo = File('build/benchmarks/micro/$nombre.json');
      archivo.parent.createSync(recursive: true);
      archivo.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(_resultados),
      );
    });
    cuerpo();
  });
}

void _registrar(String nombre, double valor, double presupuesto, String unidad) {
  _resultados[nombre] = {
    'valor': double.parse(valor.toStringAsFixed(3)),
    'presupuesto': presupuesto,
    'unidad': unidad,
  };
  // ignore: avoid_print
  print('[benchmark] $nombre: ${valor.toStringAsFixed(3)} $unidad '
      '(presupuesto $presupuesto $unidad)');
}

/// Mide una operación síncrona con benchmark_harness: µs por llamada a
/// [operacion]. [preparar] corre una vez antes y no se mide.
void microBenchmark(
  String nombre,
  void Function() operacion, {
  required double presupuestoUs,
  void Function()? preparar,
}) {
  test(nombre, () {
    preparar?.call();
    BenchmarkBase.measureFor(operacion, 100);
    final us = BenchmarkBase.measureFor(operacion, _duracionMs);
    _registrar(nombre, us, presupuestoUs, 'µs/op');
    expect(us, lessThan(presupuestoUs), reason: 'regresión en $nombre');
  });
}

/// Como [microBenchmark] para operaciones asíncronas (cubits, blocs y
/// repositorios fake): µs por `await operacion()`.
void microBenchmarkAsync(
  String nombre,
  Future<void> Function() operacion, {
  required double presupuestoUs,
  Future<void> Function()? preparar,
}) {
  test(nombre, () async {
    await preparar?.call();
    await AsyncBenchmarkBase.measureFor(operacion, 100);
    final us = await AsyncBenchmarkBase.measureFor(operacion, _duracionMs);
    _registrar(nombre, us, presupuestoUs, 'µs/op');
    expect(us, lessThan(presupuestoUs), reason: 'regresión en $nombre');
  });
}

/// Mide cuánto tarda en montarse desde cero (build + layout + paint) el
/// widget que devuelve [construir]: ms promedio de [repeticiones] montajes,
/// desmontando entre uno y otro para que no se reutilice el árbol.
void widgetBenchmark(
  String nombre,
  Widget Function() construir, {
  required double presupuestoMs,
  int repeticiones = 20,
  Size tamano = const Size(412, 915),
}) {
  testWidgets(nombre, (tester) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Warmup: la primera vez compila y cachea más de la cuenta.
    await tester.pumpWidget(construir());
    await tester.pumpWidget(const SizedBox());

    final reloj = Stopwatch();
    for (var i = 0; i < repeticiones; i++) {
      reloj.start();
      await tester.pumpWidget(construir());
      reloj.stop();
      await tester.pumpWidget(const SizedBox());
    }
    final ms = reloj.elapsedMicroseconds / repeticiones / 1000;
    _registrar(nombre, ms, presupuestoMs, 'ms/montaje');
    expect(ms, lessThan(presupuestoMs), reason: 'regresión en $nombre');
  });
}
