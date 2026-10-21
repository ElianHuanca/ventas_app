/// Lo que hace cada dispositivo: las mismas llamadas y los mismos parámetros
/// que mandan los datasources de la app. Los datasources usan el cliente
/// global (`SupabaseConfig.client`), así que no sirven para simular varios
/// dispositivos a la vez. Si cambia el contrato de una RPC, actualizar acá.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Día de [fecha] como lo guarda la app (`YYYY-MM-DD`, hora local): la venta
/// del día (`left(fecha, 10)`) y la fecha de la producción.
String dia(DateTime fecha) => fecha.toIso8601String().substring(0, 10);

/// `VentasApliquesDatasourceImpl.createVentaAplique` (RPC
/// `crear_venta_apliques`) con una línea. El total de la venta es el de la
/// línea menos el descuento, como lo arma `VentaApliquesFormCubit`.
Future<int> venderApliques(
  SupabaseClient db, {
  required int sucursal,
  required int aplique,
  required int color,
  required num cantidad,
  required num precio,
  required DateTime fecha,
  num costo = 5,
  num descuento = 0,
}) async {
  final total = cantidad * precio;
  final ganancias = (precio - costo) * cantidad;
  final idventa = await db.rpc<dynamic>('crear_venta_apliques', params: {
    'p_idsucursales': sucursal,
    'p_fecha': fecha.toIso8601String(),
    'p_total': total - descuento,
    'p_ganancias': ganancias,
    'p_descuento': descuento,
    'p_detalles': [
      {
        'idapliques': aplique,
        'idcolor': color,
        'nombre': 'CC aplique $aplique',
        'precio': precio,
        'cantidad': cantidad,
        'total': total,
        'ganancias': ganancias,
      },
    ],
  });
  return idventa as int;
}

/// `ApliquesDatasourceImpl.createProduccion` (RPC `registrar_produccion`) con
/// una línea. Devuelve el id de la producción del día.
Future<int> fabricar(
  SupabaseClient db, {
  required int sucursal,
  required int aplique,
  required int color,
  required num cantidad,
  required DateTime fecha,
}) async {
  final idproduccion = await db.rpc<dynamic>('registrar_produccion', params: {
    'p_sucursal_id': sucursal,
    'p_fecha': dia(fecha),
    'p_lineas': [
      {'idaplique': aplique, 'idcolor': color, 'cantidad': cantidad},
    ],
  });
  return idproduccion as int;
}

/// El insert de `VentasDatasourceImpl.createVenta`, sin su `catch` del
/// `23505`: el test mira qué devuelve la base.
Future<Map<String, dynamic>> insertarVentaTelas(
        SupabaseClient db, int sucursal, DateTime fecha) =>
    db
        .from('ventas')
        .insert({
          'fecha': fecha.toIso8601String(),
          'total': 0,
          'ganancias': 0,
          'descuento': 0,
          'idsucursales': sucursal,
        })
        .select()
        .single();

/// `VentasDatasourceImpl.getVentaByFecha`: lo que hace `createVenta` cuando
/// el insert choca con el UNIQUE `(idsucursales, día)`.
Future<Map<String, dynamic>?> buscarVentaTelasDelDia(
        SupabaseClient db, int sucursal, DateTime fecha) =>
    db
        .from('ventas')
        .select()
        .eq('idsucursales', sucursal)
        .like('fecha', '${dia(fecha)}%')
        .maybeSingle();

/// `DetalleVentasDatasourceImpl.createDetalleVenta` (RPC
/// `registrar_detalle_venta`) con una línea.
Future<void> registrarDetalleVenta(
  SupabaseClient db, {
  required int venta,
  required int tela,
  required num precio,
  required num cantidad,
  required num compra,
}) =>
    db.rpc('registrar_detalle_venta', params: {
      'p_idventa': venta,
      'p_detalles': [
        {
          'idtelas': tela,
          'nombre': 'CC tela $tela',
          'precio': precio,
          'cantidad': cantidad,
          'total': cantidad * precio,
          'ganancias': (precio - compra) * cantidad,
        },
      ],
    });

/// `VentasDatasourceImpl.actualizarVenta` (RPC `incrementar_venta`): suma
/// DELTAS a la venta.
Future<void> incrementarVenta(
  SupabaseClient db,
  int venta, {
  num total = 0,
  num ganancias = 0,
  num descuento = 0,
}) =>
    db.rpc('incrementar_venta', params: {
      'p_id': venta,
      'p_total': total,
      'p_ganancias': ganancias,
      'p_descuento': descuento,
      'p_fecha': null,
    });
