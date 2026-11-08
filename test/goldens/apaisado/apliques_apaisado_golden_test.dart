@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../escenarios/escenarios.dart';
import '../golden_helpers.dart';

// `/apliques`, `/aplique/:id` y `/aplique-colores/:id`.
void main() => capturasDeApliques(apaisado, todosLosEstados: true);
