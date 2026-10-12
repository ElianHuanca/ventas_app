// Capturas de cada pantalla en un Android de gama baja (360×640 dp) con la
// letra del sistema en "Grande" (1.3): ahí es donde aparecen los textos que
// desbordan, se cortan o se solapan. Arman las pantallas igual que las
// capturas de test/goldens/<feature>/, con los mismos fakes y fechas fijas.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../golden_helpers.dart';

/// [montarParaCaptura] en el [telefonoChico] con [letraGrande].
Future<void> montarChica(
  WidgetTester tester,
  Widget pantalla, {
  List<RouteBase> rutas = const [],
  bool asentar = true,
}) =>
    montarParaCaptura(
      tester,
      pantalla,
      tamano: telefonoChico,
      escalaTexto: letraGrande,
      rutas: rutas,
      asentar: asentar,
    );

/// Compara con `goldens/<pantalla>_chica.png`.
Future<void> compararChica(String pantalla) =>
    compararCaptura('${pantalla}_chica');
