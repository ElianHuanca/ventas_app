@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../escenarios/escenarios.dart';
import '../golden_helpers.dart';

// `/inventario` y `/inventario/:idsucursal`.
void main() => capturasDeInventario(tablet);
