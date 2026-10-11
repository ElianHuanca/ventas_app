// Helpers de los macro-benchmarks (benchmark/macro/). Comandos y qué miden:
// cabecera de app_benchmark.dart.
//
// Reutilizan los helpers y la creación de datos de integration_test/ sin
// tocarlos; acá solo está lo que agrega la medición.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/ventas/infrastructure/infrastructure.dart';

import '../../integration_test/datos.dart';
import '../../integration_test/helpers.dart';

/// Repeticiones de cada latencia (el driver informa mínimo, mediana y máximo).
const repeticiones = int.fromEnvironment('BM_REPETICIONES', defaultValue: 3);

/// Streams del timeline que usa `TimelineSummary` (frames de la UI,
/// rasterizador, vsync y GC). Con `all` cada traza pesa decenas de MB.
const streamsTimeline = ['Dart', 'Embedder', 'GC'];

/// Sufijo de la clave de `watchPerformance` en `reportData` (la de
/// `traceAction` es la clave sola). Mismo valor en test_driver/perf_driver.dart.
const sufijoFrames = '.frames';

/// El binding de integration_test con el `TestTextInput` registrado.
///
/// integration_test deja el teclado real y `tester.enterText` manda el texto
/// con el id de cliente -1, que el framework acepta solo en debug (dentro de
/// un assert): en profile el texto se descarta en silencio y los campos
/// quedan vacíos. Registrado, el texto entra en cualquier modo, como en los
/// tests de widget; el teclado del sistema no aparece (su animación es del
/// sistema operativo y no se mide).
class BindingBenchmark extends IntegrationTestWidgetsFlutterBinding {
  @override
  bool get registerTestTextInput => true;
}

IntegrationTestWidgetsFlutterBinding get binding =>
    IntegrationTestWidgetsFlutterBinding.instance;

Map<String, dynamic> get _reporte => binding.reportData ??= <String, dynamic>{};

void registrarEntorno() {
  final vista = binding.platformDispatcher.views.first;
  _reporte['entorno'] = {
    'modo': kReleaseMode
        ? 'release'
        : kProfileMode
            ? 'profile'
            : 'debug',
    'plataforma': defaultTargetPlatform.name,
    'pantalla': '${vista.physicalSize.width.round()}x'
        '${vista.physicalSize.height.round()} @${vista.devicePixelRatio}',
    'repeticiones': repeticiones,
    'volumen': {
      'telas': telasMasivas,
      'apliques': apliquesMasivos,
      'colores': coloresMasivos,
    },
  };
}

/// integration_test no cuenta las fallas de `setUpAll`/`tearDownAll` (el
/// driver diría "All tests passed"): se reportan acá y el driver sale con
/// error.
Future<void> reportandoErrores(
    String etapa, Future<void> Function() cuerpo) async {
  try {
    await cuerpo();
  } catch (e) {
    (_reporte.putIfAbsent('errores', () => <String>[]) as List)
        .add('$etapa: $e');
    rethrow;
  }
}

/// Deja el timeline grabando [streamsTimeline] desde el arranque: así las
/// latencias medidas antes y después de la primera traza pagan el mismo costo
/// de grabación. De paso conecta con el VM service; si no puede (DDS), falla
/// acá y no después de varios minutos de flujos.
Future<void> iniciarTimeline() =>
    binding.traceTimeline(() async {}, streams: streamsTimeline);

/// Mide la fluidez de [interaccion]: el `FrameTiming` de cada frame (build y
/// raster, vía `watchPerformance`, clave `<clave>.frames`) y el timeline
/// (`traceAction`, clave `<clave>`), que el driver resume con
/// `TimelineSummary`.
///
/// Mientras dura, los frames los pide el framework (`benchmarkLive`) como en
/// la app real: con la política por defecto solo se dibuja cuando el test
/// bombea y un scroll o una animación saldrían a 10 fps.
Future<void> medirFluidez(
    String clave, Future<void> Function() interaccion) async {
  final politica = binding.framePolicy;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;
  try {
    // watchPerformance va afuera: traza el GC con su propio traceTimeline y,
    // si quedara adentro, dejaría el timeline de traceAction sin frames.
    await binding.watchPerformance(
      () => binding.traceAction(
        () async {
          await interaccion();
          // Los FrameTiming llegan en tandas de 100 ms (debug/profile)
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        streams: streamsTimeline,
        reportKey: clave,
      ),
      reportKey: '$clave$sufijoFrames',
    );
  } finally {
    binding.framePolicy = politica;
  }
}

/// Mide desde [accion] (un toque) hasta que aparece [listo] y guarda la
/// muestra en `latencias.<clave>` (ms). Revisa en cada frame: `esperarHasta`
/// lo hace cada 100 ms y la latencia saldría redondeada a eso.
Future<void> medirLatencia(
  WidgetTester tester,
  String clave,
  Future<void> Function() accion, {
  required Finder listo,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final reloj = Stopwatch()..start();
  await accion();
  while (listo.evaluate().isEmpty) {
    if (reloj.elapsed > timeout) {
      // Falla con el mismo detalle (lo que hay en pantalla) que esperarHasta
      await esperarHasta(tester, listo, timeout: Duration.zero);
    }
    await tester.pump();
  }
  reloj.stop();
  final ms = reloj.elapsedMicroseconds / 1000;
  final latencias = _reporte.putIfAbsent('latencias', () => <String, dynamic>{})
      as Map<String, dynamic>;
  (latencias.putIfAbsent(clave, () => <double>[]) as List).add(ms);
  debugPrint('[macro] $clave: ${ms.toStringAsFixed(1)} ms');
}

/// Lleva [finder] a la vista, como `tocar` pero sin tocarlo, para que el
/// toque medido sea solo el toque.
Future<void> asegurarVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// Saca el snackbar de la acción anterior: si siguiera a la vista, la
/// medición siguiente lo encontraría en 0 ms.
Future<void> limpiarSnacks(WidgetTester tester) async {
  tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
      .clearSnackBars();
  await tester.pumpAndSettle();
}

/// Flings sobre la lista vertical de la pantalla: [veces] hacia abajo y otras
/// tantas hacia arriba (vuelve a donde estaba), cada uno hasta que frena.
Future<void> recorrerLista(WidgetTester tester, {int veces = 6}) async {
  for (final sentido in const [-1.0, 1.0]) {
    for (var i = 0; i < veces; i++) {
      await tester.fling(listaVertical.first, Offset(0, 500 * sentido), 3000);
      await tester.pumpAndSettle();
    }
  }
}

/// Escribe [texto] de a una letra (~7 por segundo) y lo borra de a una:
/// cada cambio vuelve a filtrar la lista.
Future<void> tipear(WidgetTester tester, Finder campo, String texto) async {
  const pausa = Duration(milliseconds: 150);
  for (var i = 1; i <= texto.length; i++) {
    await tester.enterText(campo, texto.substring(0, i));
    await tester.pump(pausa);
  }
  for (var i = texto.length - 1; i >= 0; i--) {
    await tester.enterText(campo, texto.substring(0, i));
    await tester.pump(pausa);
  }
}

/// En un `showDateRangePicker` abierto escribe el rango (modo texto, como
/// `elegirRango`) y mide desde Aceptar hasta que aparece [listo].
Future<void> medirRango(WidgetTester tester, String clave, DateTime desde,
    DateTime hasta, Finder listo) async {
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  final campos = find.descendant(
      of: find.byType(Dialog), matching: find.byType(TextField));
  final textos = MaterialLocalizations.of(tester.element(campos.first));
  await tester.enterText(campos.first, textos.formatCompactDate(desde));
  await tester.enterText(campos.last, textos.formatCompactDate(hasta));
  await tester.pumpAndSettle();
  await medirLatencia(
      tester, clave, () => tester.tap(find.text(textos.okButtonLabel)),
      listo: listo);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Datos
// ---------------------------------------------------------------------------

/// Como `Datos` de los tests de integración, con prefijo `BM `. Recuerda las
/// sucursales que crea para darlas de baja al terminar.
class DatosBM extends Datos {
  static final sucursalesCreadas = <int>[];

  @override
  String nombre(String base) => 'BM $base $sufijo';

  @override
  Future<Sucursal> sucursal([String base = 'Sucursal']) async {
    final creada = await super.sucursal(base);
    sucursalesCreadas.add(creada.id);
    return creada;
  }
}

/// Volumen para que haya scroll real. Nombres fijos (`BM Tela 001`...): se
/// crean una sola vez y todas las corridas miden con la misma cantidad.
const telasMasivas = 150;
const apliquesMasivos = 150;
const coloresMasivos = 40;

String nombreMasivo(String base, int i) =>
    'BM $base ${i.toString().padLeft(3, '0')}';

/// `_` es un carácter en LIKE: solo los masivos, no `BM Tela venta <sufijo>`.
String _patronMasivo(String base) => 'BM $base ___';

/// Las ventas masivas (una línea por tela, cantidad = su número) caen en un
/// mes sin otros datos —los de integración usan enero de 2020 y el selector
/// no acepta antes de 2020—, así que el ranking de ese período es solo el
/// volumen y lo encabeza la última tela.
final desdeMasivo = DateTime(2020, 6, 1);
final hastaMasivo = DateTime(2020, 6, 30);
final primeraDelRanking = nombreMasivo('Tela', telasMasivas);
const _sucursalMasiva = 'BM Sucursal masiva';

/// Crea lo que falte del volumen y lo activa. Requiere sesión.
Future<void> asegurarVolumen() async {
  await _completar(
      'telas',
      'Tela',
      telasMasivas,
      (i) => {
            'precxmen': 20 + i % 10,
            'precxmay': 18 + i % 10,
            'precxrollo': 15 + i % 10,
            'precxcompra': 10,
          });
  await _completar(
      'apliques',
      'Aplique',
      apliquesMasivos,
      (i) => {
            'costo_fabricacion': 3 + i % 5,
            'ancho_cm': 2 + i % 8,
            'alto_cm': 2 + i % 6,
          });
  await _completar('colores', 'Color', coloresMasivos, (i) => {'hex': _hex(i)});
  await activarVolumen(true);
  await _asegurarVentasMasivas();
}

/// Activa o da de baja (baja lógica) el volumen. Se da de baja al terminar
/// para no alargar las listas de los tests de integración: por orden
/// alfabético `BM` queda antes que `IT` y `scrollUntilVisible` no llegaría.
Future<void> activarVolumen(bool activo) async {
  for (final (tabla, base) in const [
    ('telas', 'Tela'),
    ('apliques', 'Aplique'),
    ('colores', 'Color'),
  ]) {
    await db
        .from(tabla)
        .update({'activo': activo}).like('nombre', _patronMasivo(base));
  }
}

/// Al terminar: baja lógica del volumen y de las sucursales de cada flujo.
Future<void> darDeBajaLoDelBenchmark() async {
  await iniciarSesionDirecto();
  await activarVolumen(false);
  if (DatosBM.sucursalesCreadas.isNotEmpty) {
    await db
        .from('sucursales')
        .update({'activo': false}).inFilter('id', DatosBM.sucursalesCreadas);
  }
  await cerrarSesionDirecto();
}

Future<void> _completar(String tabla, String base, int cantidad,
    Map<String, Object> Function(int i) columnas) async {
  final existentes =
      await db.from(tabla).select('nombre').like('nombre', _patronMasivo(base));
  final nombres = {for (final fila in existentes) fila['nombre'] as String};
  final faltan = [
    for (var i = 1; i <= cantidad; i++)
      if (!nombres.contains(nombreMasivo(base, i)))
        {'nombre': nombreMasivo(base, i), 'activo': true, ...columnas(i)},
  ];
  if (faltan.isNotEmpty) await db.from(tabla).insert(faltan);
}

String _hex(int i) =>
    ((i * 0x9E3779) & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

Future<void> _asegurarVentasMasivas() async {
  final filas = await db
      .from('sucursales')
      .select('id')
      .eq('nombre', _sucursalMasiva)
      .limit(1);
  // Inactiva: solo sostiene las ventas, no aparece en las grillas
  final idsucursal = filas.isNotEmpty
      ? filas.single['id'] as int
      : (await SucursalesDatasourceImpl()
              .createSucursal({'nombre': _sucursalMasiva, 'activo': false}))
          .id;
  // Devuelve la existente si ya está la de ese día
  final venta = await VentasDatasourceImpl()
      .createVenta(idsucursal, DateTime(2020, 6, 15, 10));
  final conLinea = {
    for (final fila in await db
        .from('detalle_ventas')
        .select('idtelas')
        .eq('idventa', venta.id))
      fila['idtelas'],
  };
  final telas = await db
      .from('telas')
      .select('id, nombre')
      .like('nombre', _patronMasivo('Tela'));
  final lineas = [
    for (final tela in telas)
      if (!conLinea.contains(tela['id'])) _lineaMasiva(tela),
  ];
  if (lineas.isEmpty) return;
  await DetalleVentasDatasourceImpl().createDetalleVenta(lineas, venta.id);
}

Map<String, dynamic> _lineaMasiva(Map<String, dynamic> tela) {
  final nombre = tela['nombre'] as String;
  final cantidad = int.parse(nombre.substring(nombre.length - 3));
  return {
    'idtelas': tela['id'],
    'nombre': nombre,
    'precio': 20,
    'cantidad': cantidad,
    'total': 20 * cantidad,
    'ganancias': 10 * cantidad,
  };
}
