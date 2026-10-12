// Los tests de accesibilidad montan las pantallas con las fuentes reales
// (Roboto y MaterialIcons del SDK), igual que las capturas golden: con la
// fuente de prueba de flutter_test (Ahem, cada letra un cuadrado) el texto es
// más ancho que en el celular y varias pantallas desbordan a 412 dp, y el
// contraste se mediría sobre glifos que no son los reales.
//
// Flutter usa solo el flutter_test_config.dart más cercano, así que acá se
// encadenan los dos: las fuentes de las capturas y el rastreo de fugas de
// test/flutter_test_config.dart.
import 'dart:async';

import '../flutter_test_config.dart' as fugas;
import '../goldens/flutter_test_config.dart' as fuentes;

Future<void> testExecutable(FutureOr<void> Function() testMain) =>
    fuentes.testExecutable(() => fugas.testExecutable(testMain));
