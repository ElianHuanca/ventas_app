import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:textiles_app/config/config.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/colores/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/ventas/infrastructure/infrastructure.dart';

import 'helpers.dart';

SupabaseClient get db => SupabaseConfig.client;

double numero(dynamic valor) => (valor as num).toDouble();

/// Datos propios de cada test, creados con los datasources reales de la app
/// (mismas tablas, RLS y RPC que usa la UI). Todos llevan el prefijo `IT ` y
/// un sufijo único: la base no permite borrarlos y se limpian con
/// `npx supabase@latest db reset`.
class Datos {
  final String sufijo = sufijoUnico();

  String nombre(String base) => 'IT $base $sufijo';

  /// La base exige login y estos datos se crean con los datasources de la
  /// app. Si el test todavía no inició sesión (corrido solo, después del
  /// setUpAll, que la cierra), la inicia: si no, dependía de que un test
  /// anterior la hubiera dejado abierta.
  Future<void> _conSesion() async {
    if (db.auth.currentSession == null) await iniciarSesionDirecto();
  }

  Future<Sucursal> sucursal([String base = 'Sucursal']) async {
    await _conSesion();
    return SucursalesDatasourceImpl().createSucursal({'nombre': nombre(base)});
  }

  Future<Tela> tela(String base, {num precio = 25, num compra = 15}) async {
    await _conSesion();
    return TelasDatasourceImpl().createTela({
      'nombre': nombre(base),
      'precxmen': precio,
      'precxmay': precio,
      'precxrollo': precio,
      'precxcompra': compra,
      'activo': true,
    });
  }

  Future<ColorItem> color(String base, {String hex = 'C0392B'}) async {
    await _conSesion();
    return ColoresDatasourceImpl()
        .createColor({'nombre': nombre(base), 'hex': hex});
  }

  Future<Aplique> aplique(String base, {num costo = 5}) async {
    await _conSesion();
    return ApliquesDatasourceImpl().createAplique({
      'nombre': nombre(base),
      'costo_fabricacion': costo,
      'activo': true,
    });
  }

  Future<void> vincularColor(Aplique aplique, ColorItem color) =>
      ApliquesDatasourceImpl().setColorAplique(aplique.id, color.id, true);

  /// Habilita [tela] en la venta de [sucursal] (tela_sucursales activo).
  Future<void> ofrecerTela(Sucursal sucursal, Tela tela) =>
      SucursalesDatasourceImpl().setTelaSucursal(tela.id, sucursal.id, true);

  /// Fabricación de hoy: crea o suma el stock de inventario.
  Future<void> fabricar(
          Sucursal sucursal, Aplique aplique, ColorItem color, num cantidad) =>
      ApliquesDatasourceImpl().createProduccion(
        sucursalId: sucursal.id,
        fecha: DateTime.now(),
        lineas: [
          {'idaplique': aplique.id, 'idcolor': color.id, 'cantidad': cantidad},
        ],
      );

  /// Venta de apliques de hoy (RPC crear_venta_apliques: descuenta stock).
  Future<void> venderApliques(Sucursal sucursal, Aplique aplique,
      ColorItem color, num cantidad, num precio,
      {num costo = 5}) {
    final total = cantidad * precio;
    final ganancias = (precio - costo) * cantidad;
    return VentasApliquesDatasourceImpl().createVentaAplique(
      idsucursales: sucursal.id,
      total: total.toDouble(),
      ganancias: ganancias.toDouble(),
      descuento: 0,
      detalles: [
        {
          'idapliques': aplique.id,
          'idcolor': color.id,
          'nombre': '${aplique.nombre} (${color.nombre})',
          'precio': precio,
          'cantidad': cantidad,
          'total': total,
          'ganancias': ganancias,
        },
      ],
    );
  }

  /// Venta de telas (de hoy, salvo otra [fecha]) con una línea, sin tocar los
  /// totales de la cabecera: alcanza para el ranking del dashboard.
  Future<void> venderTela(
      Sucursal sucursal, Tela tela, num cantidad, num precio,
      {DateTime? fecha}) async {
    final venta = await VentasDatasourceImpl()
        .createVenta(sucursal.id, fecha ?? DateTime.now());
    await DetalleVentasDatasourceImpl().createDetalleVenta([
      {
        'idtelas': tela.id,
        'nombre': tela.nombre,
        'precio': precio,
        'cantidad': cantidad,
        'total': cantidad * precio,
        'ganancias': (precio - (tela.precxcompra ?? 0)) * cantidad,
      },
    ], venta.id);
  }
}

Future<double> stockDe(
    Sucursal sucursal, Aplique aplique, ColorItem color) async {
  final fila = await db
      .from('inventario')
      .select('stock')
      .eq('sucursal_id', sucursal.id)
      .eq('aplique_id', aplique.id)
      .eq('color_id', color.id)
      .maybeSingle();
  return fila == null ? 0 : numero(fila['stock']);
}
