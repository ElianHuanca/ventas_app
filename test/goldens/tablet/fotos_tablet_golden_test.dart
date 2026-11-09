@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../escenarios/escenarios.dart';
import '../golden_helpers.dart';

// `/tela-fotos/:id` y `/aplique-fotos/:id` (la misma pantalla).
void main() => capturasDeFotos(tablet);
