// Macro-benchmarks: la app completa (HuantexApp: router, login, datasources,
// RLS y RPC) en un dispositivo contra el Supabase local, medida por flujo de
// usuario. Ver las secciones "Tests" y "Entorno local" del CLAUDE.md.
//
// Sin el sufijo _test a propósito: ni `flutter test integration_test` ni
// `flutter test benchmark/micro` lo toman. Corre con flutter drive y el
// driver test_driver/perf_driver.dart, que deja todo en build/benchmarks/macro/:
//   resultados.json                   fluidez y latencias de todos los flujos
//   <clave>.timeline.json             traza (Perfetto / chrome://tracing;
//                                     en los scrolls, solo el final)
//   <clave>.timeline_summary.json     resumen de la traza (TimelineSummary)
//
// Números de referencia SOLO en --profile y en el celular físico: los
// emuladores no soportan profile y en debug (JIT + asserts) salen varias
// veces más lentos. --no-dds hace falta para que la app se conecte a su
// propio VM service y grabe el timeline.
//
//   npx supabase@latest start -x realtime,storage-api,imgproxy,edge-runtime,logflare,vector,supavisor,mailpit
//   adb reverse tcp:54321 tcp:54321
//   flutter drive --driver=test_driver/perf_driver.dart --target=benchmark/macro/app_benchmark.dart --profile --no-dds -d <celular> --dart-define-from-file=env/local-usb.json
//
// Para comprobar que el harness corre entero (los números no valen), en debug
// en el emulador:
//   flutter drive --driver=test_driver/perf_driver.dart --target=benchmark/macro/app_benchmark.dart --no-dds -d emulator-5554 --dart-define-from-file=env/local-android.json
//
// --dart-define=BM_REPETICIONES=5 cambia las repeticiones de cada latencia (3).
//
// La app tiene que quedar en primer plano y con la pantalla encendida toda la
// corrida: sin frames, watchPerformance espera para siempre ("delayForFrameTimings
// is taking longer than expected...").
//
// Qué mide (claves de resultados.json):
// - Latencia end-to-end, toque → dato visible (ms): login_a_inicio,
//   abrir_sucursales, abrir_telas, buscar_tela, abrir_colores, abrir_apliques,
//   registrar_fabricacion, registrar_venta_apliques, registrar_venta_telas,
//   cargar_dashboard, cambiar_periodo.
// - Fluidez, FrameTiming de cada frame (build/raster promedio, p90, p99,
//   frames perdidos) + timeline: login, sucursales_navegacion,
//   sucursales_scroll, telas_scroll, telas_busqueda, colores_scroll,
//   apliques_scroll, fabricacion_formulario, venta_apliques_formulario,
//   venta_telas_formulario, dashboard_pestanas, dashboard_scroll,
//   menu_lateral, navegacion_menu.
//
// Datos: cada flujo crea los suyos con prefijo `BM ` (como los `IT ` de los
// tests de integración). Para que haya scroll real se crean una sola vez 150
// telas, 150 apliques y 40 colores (`BM Tela 001`...) y una venta de junio de
// 2020 con una línea por tela; se activan al empezar y se dan de baja
// (activo = false) al terminar, igual que las sucursales de cada flujo. La
// base no permite borrar: se limpia con `npx supabase@latest db reset`.
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/helpers.dart';
import 'flujos.dart';
import 'medicion.dart';

void main() {
  // En vez de IntegrationTestWidgetsFlutterBinding.ensureInitialized(): sin
  // esto tester.enterText no escribe en profile (ver BindingBenchmark)
  BindingBenchmark();

  setUpAll(() => reportandoErrores('setUpAll', () async {
        registrarEntorno();
        await prepararBaseLocal();
        // Antes que los datos: sin --no-dds falla acá, en segundos
        await iniciarTimeline();
        await iniciarSesionDirecto();
        await asegurarVolumen();
        await cerrarSesionDirecto();
      }));
  tearDownAll(() => reportandoErrores('tearDownAll', darDeBajaLoDelBenchmark));

  benchmarkLogin();
  benchmarkSucursales();
  benchmarkTelas();
  benchmarkColores();
  benchmarkApliques();
  benchmarkFabricacion();
  benchmarkVentaApliques();
  benchmarkVentaTelas();
  benchmarkDashboard();
  benchmarkMenu();
}
