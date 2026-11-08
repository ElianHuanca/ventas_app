@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../escenarios/escenarios.dart';
import '../golden_helpers.dart';

// `/dashboard/telas`, `/dashboard/apliques`, `/login` y el menú lateral abierto.
void main() => capturasDeDashboardLoginMenu(pantallaChica);
