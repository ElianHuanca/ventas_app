@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../escenarios/escenarios.dart';
import '../golden_helpers.dart';

// `/telas`, `/tela/:id` y `/tela-colores/:id`.
void main() => capturasDeTelas(apaisado, todosLosEstados: true);
