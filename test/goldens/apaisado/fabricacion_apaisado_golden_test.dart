@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../escenarios/escenarios.dart';
import '../golden_helpers.dart';

// `/fabricacion`, `/fabricacion/:idsucursal`, `/fabricacion/registro/:idsucursal` y
// `/fabricacion/detalle/:idproduccion`.
void main() => capturasDeFabricacion(apaisado, todosLosEstados: true);
