@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../escenarios/escenarios.dart';
import '../golden_helpers.dart';

// `/ventas/:idsucursal`, `/det_ventas/:idventa` y `/det_venta/:idsucursal`.
void main() => capturasDeVentas(pantallaChica);
