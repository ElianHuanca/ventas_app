@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../escenarios/escenarios.dart';
import '../golden_helpers.dart';

// `/venta-apliques`, `/venta-apliques/:idsucursal`,
// `/venta-apliques/registro/:idsucursal` y `/venta-apliques/detalle/:idventa`.
void main() => capturasDeVentaApliques(apaisado, todosLosEstados: true);
