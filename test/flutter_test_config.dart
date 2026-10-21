// Configuración de todos los tests de test/: rastreo de fugas de memoria.
//
// Con LeakTesting.enable() cada `testWidgets` registra los objetos de Flutter
// que avisan su creación y su dispose() (TextEditingController,
// ChangeNotifier/ValueNotifier, AnimationController, FocusNode,
// ScrollController…). Al terminar el archivo, si alguno no se liberó el test
// falla y lista qué clase quedó viva y en qué test se creó.
//
// Qué hacer con una fuga:
// - de lib/ (falta un dispose(), un controller creado en build, un listener sin
//   quitar): arreglarla en lib/;
// - del propio test (un controller creado en el test): `addTearDown(x.dispose)`;
// - solo si es del framework o de un paquete y no tiene arreglo: ignorarla
//   acá abajo (withIgnored) con un comentario de qué y por qué.
//
// Para ver dónde se creó el objeto que quedó vivo:
//   flutter test <archivo> --dart-define=FUGAS_CON_PILA=true
//
// Flutter usa el flutter_test_config.dart MÁS CERCANO al test (no los encadena):
// test/goldens/ tiene el suyo (carga las fuentes de las capturas) y
// benchmark/micro/widgets/ lo reexporta, así que esta configuración no aplica a
// las capturas ni a los benchmarks: las fugas se buscan en los tests de widget
// de test/features y test/config, que montan las mismas pantallas.
//
// Los Bloc/Cubit no los ve leak_tracker (no avisan su creación a Flutter): los
// que crea un BlocProvider(create:) se cierran solos; los creados a mano hay
// que cerrarlos con close().
import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  // flutter_tester corre en la VM de Dart, que leak_tracker soporta: no hace
  // falta el aviso de plataforma no soportada (web).
  LeakTracking.warnForUnsupportedPlatforms = false;

  var ajustes = LeakTesting.settings.withIgnored(
    notDisposed: {
      // Del binding de flutter_test, no de la app: lo crea a demanda (p. ej.
      // cuando un TabBarView/PageView guarda su posición) y lo libera recién
      // en reset(), al EMPEZAR el test siguiente. El del último test del
      // archivo sigue vivo cuando se cuentan las fugas. Se tolera uno por test
      // (con su bucket raíz): un segundo sí se reporta.
      'TestRestorationManager': 1,
      'RestorationBucket': 1,
    },
  );
  if (const bool.fromEnvironment('FUGAS_CON_PILA')) {
    ajustes = ajustes.withCreationStackTrace();
  }
  LeakTesting.settings = ajustes;

  await testMain();
}
