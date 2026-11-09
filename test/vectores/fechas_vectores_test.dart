import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/changeFormatDate.dart';
import 'package:textiles_app/features/ventas/infrastructure/infrastructure.dart';

import 'supabase_de_prueba.dart';
import 'vectores.dart';

/// `test/vectores/fechas.json` con `changeFormatDate` y el `p_fecha` que
/// manda `VentasDatasourceImpl.registrarVentaTelas` (por una red de mentira).
void main() {
  late RedDePrueba red;
  setUpAll(() async => red = await abrirSupabaseDePrueba());

  probarVectores('fechas', (caso) async {
    final fecha = DateTime.parse(caso.entrada['fecha'] as String);
    switch (caso.entrada['funcion']) {
      case 'changeFormatDate':
        expect(changeFormatDate(fecha), caso.esperado);
      case 'dia_de_la_venta':
        red
          ..pedidos.clear()
          ..responder = (_) => 1;
        await VentasDatasourceImpl().registrarVentaTelas(
          idsucursal: 1,
          fecha: fecha,
          detalles: const [],
          descuento: 0,
        );
        final params = red.pedidos.single.json! as Map<String, dynamic>;
        expect((params['p_fecha'] as String).substring(0, 10), caso.esperado);
      default:
        fail('función desconocida: ${caso.entrada['funcion']}');
    }
  });
}
