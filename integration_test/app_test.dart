// Tests de integración: la app completa contra el Supabase local (Docker),
// con login, navegación, RLS y RPC reales. Ver la sección "Tests" del CLAUDE.md.
//
// Un solo punto de entrada (la app se compila e instala una vez); los flujos
// están en flujos/ sin el sufijo _test para que flutter test no los tome
// como entradas sueltas.
//
//   npx supabase@latest start -x realtime,storage-api,imgproxy,edge-runtime,logflare,vector,supavisor,mailpit
//   adb reverse tcp:54321 tcp:54321
//   flutter test integration_test -d <celular> --dart-define-from-file=env/local-usb.json
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'flujos/apliques.dart';
import 'flujos/auth.dart';
import 'flujos/colores.dart';
import 'flujos/dashboard.dart';
import 'flujos/fabricacion.dart';
import 'flujos/inventario.dart';
import 'flujos/sucursales.dart';
import 'flujos/telas.dart';
import 'flujos/venta_apliques.dart';
import 'flujos/venta_telas.dart';
import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(prepararBaseLocal);

  authTests();
  sucursalesTests();
  telasTests();
  coloresTests();
  apliquesTests();
  fabricacionTests();
  ventaApliquesTests();
  inventarioTests();
  ventaTelasTests();
  dashboardTests();
}
