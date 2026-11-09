import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/ventas/infrastructure/infrastructure.dart';

import 'supabase_de_prueba.dart';
import 'vectores.dart';

/// `test/vectores/params_rpc.json`: el cuerpo que mandan a la base los
/// datasources reales de Flutter (por una red de mentira).
void main() {
  late RedDePrueba red;
  setUpAll(() async => red = await abrirSupabaseDePrueba());

  probarVectores('params_rpc', (caso) async {
    final e = caso.entrada;
    red.pedidos.clear();
    red.responder = (p) => p.rpc == 'inventario_con_ventas' ? <Object>[] : 1;

    switch (e['rpc']) {
      case 'registrar_venta_telas':
        await VentasDatasourceImpl().registrarVentaTelas(
          idsucursal: e['idsucursal'] as int,
          fecha: DateTime.parse(e['fecha'] as String),
          detalles: _filas(e['detalles']),
          descuento: (e['descuento'] as num).toDouble(),
          idOperacion: e['id_operacion'] as String?,
        );
      case 'crear_venta_apliques':
        await VentasApliquesDatasourceImpl().createVentaAplique(
          idsucursales: e['idsucursales'] as int,
          total: (e['total'] as num).toDouble(),
          ganancias: (e['ganancias'] as num).toDouble(),
          descuento: (e['descuento'] as num).toDouble(),
          detalles: _filas(e['detalles']),
          idOperacion: e['id_operacion'] as String?,
        );
      case 'registrar_produccion':
        await ApliquesDatasourceImpl().createProduccion(
          sucursalId: e['sucursal_id'] as int,
          fecha: DateTime.parse(e['fecha'] as String),
          lineas: _filas(e['lineas']),
          idOperacion: e['id_operacion'] as String?,
        );
      case 'inventario_con_ventas':
        await ApliquesDatasourceImpl().getInventarioConVentas(
          e['sucursal_id'] as int,
          desde: DateTime.parse(e['desde'] as String),
          hasta: DateTime.parse(e['hasta'] as String),
        );
      default:
        fail('RPC desconocida: ${e['rpc']}');
    }

    expect(red.pedidos.map((p) => p.rpc), [e['rpc']],
        reason: 'una sola llamada, a esa RPC');
    final params =
        Map<String, dynamic>.of(red.pedidos.single.json! as Map<String, dynamic>);
    final esperado = Map<String, dynamic>.of(caso.esperado! as Map<String, dynamic>);
    if (esperado['p_fecha'] == ahora) {
      expect(params['p_fecha'], isA<String>());
      expectAhora(DateTime.parse(params['p_fecha'] as String), donde: 'p_fecha');
      params.remove('p_fecha');
      esperado.remove('p_fecha');
    }
    expectComoVector(params, esperado);
  });
}

List<Map<String, dynamic>> _filas(Object? lista) =>
    [for (final f in lista! as List) Map<String, dynamic>.of(f as Map<String, dynamic>)];
