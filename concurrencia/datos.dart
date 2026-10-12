/// Datos propios de los tests de concurrencia y las lecturas para verificar
/// qué quedó en la base.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'operaciones.dart';

double numero(dynamic valor) => (valor as num).toDouble();

/// Montos de dinero en centavos, para comparar sumas sin error de coma
/// flotante (las columnas de ventas son `NUMERIC(14,2)`).
int centavos(dynamic valor) => (numero(valor) * 100).round();

/// Una sucursal nueva con un aplique y un color habilitado para él
/// (`aplique_colores` activo: sin el vínculo `crear_venta_apliques` rechaza
/// la venta).
class ApliqueEnSucursal {
  const ApliqueEnSucursal(this.sucursal, this.aplique, this.color);

  final int sucursal;
  final int aplique;
  final int color;
}

/// Fecha de todas las ventas y producciones de estos tests. Un día de 2001:
/// fuera del rango por defecto del dashboard (este mes) y del que usan los
/// tests de integración (enero de 2020), para no meterse en los rankings que
/// ellos recorren. Las RPC agrupan por el día de la fecha que reciben, sea
/// cual sea (la app también registra con fecha anterior), y cada vuelta usa
/// una sucursal nueva: su venta y su producción del día son solo suyas.
final fechaCC = DateTime(2001, 1, 1, 12);

/// Crea los datos de cada vuelta con las mismas tablas que las pantallas de
/// gestión. Llevan el prefijo `CC ` y un sufijo único: la base no permite
/// borrarlos (se limpian con `npx supabase@latest db reset`).
class DatosCC {
  DatosCC(this.db);

  final SupabaseClient db;
  final _sufijo = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  var _contador = 0;
  final _creados = <String, List<int>>{};

  String nombre(String base) => 'CC $base $_sufijo-${_contador++}';

  Future<int> _insertar(String tabla, Map<String, dynamic> fila) async {
    final row = await db.from(tabla).insert(fila).select('id').single();
    final id = row['id'] as int;
    (_creados[tabla] ??= []).add(id);
    return id;
  }

  /// Baja lógica (`activo = false`) de todo lo creado: así no aparece en las
  /// listas ni en los selectores de la app, ni en los de los tests de
  /// integración que corren contra la misma base.
  Future<void> darDeBaja() async {
    for (final MapEntry(key: tabla, value: ids) in _creados.entries) {
      await db.from(tabla).update({'activo': false}).inFilter('id', ids);
    }
    _creados.clear();
  }

  Future<int> sucursal() =>
      _insertar('sucursales', {'nombre': nombre('Sucursal')});

  Future<int> tela({num precio = 25, num compra = 15}) => _insertar('telas', {
        'nombre': nombre('Tela'),
        'precxmen': precio,
        'precxmay': precio,
        'precxrollo': precio,
        'precxcompra': compra,
        'activo': true,
      });

  Future<ApliqueEnSucursal> apliqueEnSucursalNueva({num costo = 5}) async {
    final sucursal = await this.sucursal();
    final color = await _insertar(
        'colores', {'nombre': nombre('Color'), 'hex': '2E86C1'});
    final aplique = await _insertar('apliques', {
      'nombre': nombre('Aplique'),
      'costo_fabricacion': costo,
      'activo': true,
    });
    await db
        .from('aplique_colores')
        .upsert({'idaplique': aplique, 'idcolor': color, 'activo': true});
    return ApliqueEnSucursal(sucursal, aplique, color);
  }
}

Future<double> stockDe(SupabaseClient db, ApliqueEnSucursal p) async {
  final fila = await db
      .from('inventario')
      .select('stock')
      .eq('sucursal_id', p.sucursal)
      .eq('aplique_id', p.aplique)
      .eq('color_id', p.color)
      .maybeSingle();
  return fila == null ? 0 : numero(fila['stock']);
}

/// Ventas de apliques de la sucursal en el día de [fecha] (debería haber una).
Future<List<Map<String, dynamic>>> ventasApliquesDelDia(
        SupabaseClient db, int sucursal, DateTime fecha) =>
    db
        .from('ventas_apliques')
        .select()
        .eq('idsucursales', sucursal)
        .like('fecha', '${dia(fecha)}%');

Future<List<Map<String, dynamic>>> lineasVentaApliques(
        SupabaseClient db, int idventa) =>
    db.from('detalle_ventas_apliques').select().eq('idventa', idventa);

/// Ventas de telas de la sucursal en el día de [fecha] (debería haber una).
Future<List<Map<String, dynamic>>> ventasTelasDelDia(
        SupabaseClient db, int sucursal, DateTime fecha) =>
    db
        .from('ventas')
        .select()
        .eq('idsucursales', sucursal)
        .like('fecha', '${dia(fecha)}%');

Future<Map<String, dynamic>> ventaTelas(SupabaseClient db, int id) =>
    db.from('ventas').select().eq('id', id).single();

Future<List<Map<String, dynamic>>> lineasVentaTelas(
        SupabaseClient db, int idventa) =>
    db.from('detalle_ventas').select().eq('idventa', idventa);

/// Producciones (cabeceras) de la sucursal en el día de [fecha].
Future<List<Map<String, dynamic>>> produccionesDelDia(
        SupabaseClient db, int sucursal, DateTime fecha) =>
    db
        .from('producciones')
        .select()
        .eq('sucursal_id', sucursal)
        .eq('fecha', dia(fecha));

Future<List<Map<String, dynamic>>> lineasProduccion(
        SupabaseClient db, int idproduccion) =>
    db.from('detalle_produccion').select().eq('idproduccion', idproduccion);
