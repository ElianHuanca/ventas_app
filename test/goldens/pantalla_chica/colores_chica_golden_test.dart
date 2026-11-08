@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../escenarios/escenarios.dart';
import '../golden_helpers.dart';

// `/colores` y `/color/:id`.
void main() => capturasDeColores(pantallaChica);
