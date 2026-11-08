@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../escenarios/escenarios.dart';
import '../golden_helpers.dart';

// `/`, `/sucursales`, `/sucursal/:id` y `/sucursal-disponibilidad/:id`.
void main() => capturasDeSucursales(pantallaChica);
