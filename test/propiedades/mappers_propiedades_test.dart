import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/aplique_mapper.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/produccion_mapper.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/stock_aplique_mapper.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/venta_aplique_mapper.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/infrastructure/mappers/sucursal_mapper.dart';
import 'package:textiles_app/features/sucursales/infrastructure/mappers/tela_sucursal_mapper.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/infrastructure/mappers/tela_mapper.dart';
import 'package:textiles_app/features/ventas/infrastructure/mappers/detalleVenta_mapper.dart';
import 'package:textiles_app/features/ventas/infrastructure/mappers/venta_mapper.dart';

import 'generadores.dart';

/// Los mappers con filas generadas con la forma real de PostgREST: `numeric`
/// llega como int (sin decimales) o double, `fecha` como texto ISO8601, null
/// solo en las columnas que lo permiten (schema de producción) y a veces la
/// columna ni viene (select parcial). Nunca lanzan y conservan los valores.
void main() {
  propiedad('TelaMapper', _filaTela, (fila) {
    final Tela tela = TelaMapper.jsonToEntity(fila);

    expect(tela.id, fila['id']);
    expect(tela.nombre, fila['nombre']);
    for (final (campo, valor) in [
      ('precxmen', tela.precxmen),
      ('precxmay', tela.precxmay),
      ('precxrollo', tela.precxrollo),
      ('precxcompra', tela.precxcompra),
    ]) {
      expect(valor, (fila[campo] as num).toDouble(), reason: campo);
    }
    expect(tela.activo, fila['activo']);
  });

  propiedad('SucursalMapper', _filaSucursal, (fila) {
    final Sucursal sucursal = SucursalMapper.jsonToEntity(fila);

    expect(sucursal.id, fila['id']);
    expect(sucursal.nombre, fila['nombre']);
  });

  propiedad('TelaSucursalMapper: disponible si algún vínculo está activo',
      _filaTelaSucursal, (fila) {
    final tela = TelaSucursalMapper.jsonToEntity(fila);

    expect(tela.idtela, fila['id']);
    expect(tela.nombre, fila['nombre']);
    expect(tela.disponible,
        (fila['tela_sucursales'] as List).any((v) => v['activo'] == true));
  });

  propiedad('ApliqueMapper: dimensiones null siguen null', _filaAplique,
      (fila) {
    final aplique = ApliqueMapper.jsonToEntity(fila);

    expect(aplique.id, fila['id']);
    expect(aplique.nombre, fila['nombre']);
    expect(aplique.costoFabricacion,
        (fila['costo_fabricacion'] as num).toDouble());
    expect(aplique.tamanio, fila['tamanio'] ?? '');
    expect(aplique.anchoCm, (fila['ancho_cm'] as num?)?.toDouble());
    expect(aplique.altoCm, (fila['alto_cm'] as num?)?.toDouble());
    expect(aplique.activo, fila['activo']);
  });

  propiedad('StockApliqueMapper: hex null queda vacío', _filaStock, (fila) {
    final stock = StockApliqueMapper.jsonToEntity(fila);
    final color = fila['colores'] as Map;

    expect(stock.apliqueId, fila['aplique_id']);
    expect(stock.colorId, fila['color_id']);
    expect(stock.colorNombre, color['nombre']);
    expect(stock.hex, color['hex'] ?? '');
    expect(stock.stock, (fila['stock'] as num).toDouble());
  });

  propiedad('ProduccionMapper.jsonToEntity: la fecha de la cabecera tal cual',
      _filaDetalleProduccion, (fila) {
    final produccion = ProduccionMapper.jsonToEntity(fila);
    final cabecera = fila['producciones'] as Map;

    expect(produccion.id, fila['id']);
    expect(produccion.fecha, cabecera['fecha']);
    expect(produccion.sucursalNombre, cabecera['sucursales']['nombre']);
    expect(produccion.apliqueNombre, fila['apliques']['nombre']);
    expect(produccion.colorNombre, fila['colores']['nombre']);
    expect(produccion.hex, fila['colores']['hex'] ?? '');
    expect(produccion.cantidad, (fila['cantidad'] as num).toDouble());
  });

  propiedad('ProduccionMapper.jsonToCabecera: la fecha (date) es ese día',
      _filaProduccion, (entrada) {
    final (fila, fecha) = entrada;
    final cabecera = ProduccionMapper.jsonToCabecera(fila);

    expect(cabecera.id, fila['id']);
    _mismaFecha(cabecera.fecha, fecha.esperado);
  });

  propiedad('VentaApliqueMapper.jsonToVentaAplique: fecha ISO8601', _filaVenta,
      (entrada) {
    final (fila, fecha) = entrada;
    final venta = VentaApliqueMapper.jsonToVentaAplique(fila);

    expect(venta.id, fila['id']);
    _mismaFecha(venta.fecha, fecha.esperado);
  });

  propiedad('VentaApliqueMapper.jsonToDetalle', _filaDetalleVentaAplique,
      (fila) {
    final detalle = VentaApliqueMapper.jsonToDetalle(fila);

    expect(detalle.id, fila['id']);
    expect(detalle.nombre, fila['nombre'] ?? '');
    expect(detalle.cantidad, (fila['cantidad'] as num).toDouble());
    expect(detalle.precio, (fila['precio'] as num).toDouble());
    expect(detalle.total, (fila['total'] as num).toDouble());
  });

  propiedad('VentaMapper: fecha ISO8601 y montos', _filaVenta, (entrada) {
    final (fila, fecha) = entrada;
    final venta = VentaMapper.jsonToEntity(fila);

    expect(venta.id, fila['id']);
    _mismaFecha(venta.fecha, fecha.esperado);
    expect(venta.total, (fila['total'] as num).toDouble());
    expect(venta.ganancias, (fila['ganancias'] as num).toDouble());
    expect(venta.descuento, (fila['descuento'] as num).toDouble());
    expect(venta.idsucursales, fila['idsucursales']);
  });

  propiedad(
      'DetalleVentaMapper: total/ganancias null quedan en 0', _filaDetalleVenta,
      (fila) {
    final detalle = DetalleVentaMapper.jsonToEntity(fila);

    expect(detalle.id, fila['id']);
    expect(detalle.nombre, fila['nombre']);
    expect(detalle.precio, (fila['precio'] as num).toDouble());
    expect(detalle.cantidad, (fila['cantidad'] as num).toDouble());
    expect(detalle.total, (fila['total'] as num?)?.toDouble() ?? 0);
    expect(detalle.ganancias, (fila['ganancias'] as num?)?.toDouble() ?? 0);
    expect(detalle.idtelas, fila['idtelas']);
  });

  propiedad('DetalleVenta: toJson y vuelta por el mapper conserva la línea',
      _filaDetalleVenta, (fila) {
    final original = DetalleVentaMapper.jsonToEntity(fila);
    final vuelta = DetalleVentaMapper.jsonToEntity(original.toJson());

    expect(vuelta.id, original.id);
    expect(vuelta.nombre, original.nombre);
    expect(vuelta.precio, original.precio);
    expect(vuelta.cantidad, original.cantidad);
    expect(vuelta.total, original.total);
    expect(vuelta.ganancias, original.ganancias);
    expect(vuelta.idtelas, original.idtelas);
  });
}

// --- Valores --------------------------------------------------------------

/// Columna nullable que no vino en el select: se quita de la fila.
class _Ausente {
  const _Ausente();
}

const _ausente = _Ausente();

Map<String, dynamic> _fila(Map<String, Object?> columnas) =>
    {...columnas}..removeWhere((_, v) => v is _Ausente);

/// null, ausente o un valor.
Generator<Object?> _nullable(Generator<Object?> valor) =>
    any.either(any.always<Object?>(null), any.always<Object?>(_ausente), valor);

final _id = any.entero(1, 1 << 31);

const _letras = ['a', 'Z', 'ñ', 'é', ' ', '-', "'", '"', '%', '😀', '0'];
final Generator<Object?> _texto = any.combine2(
  any.entero(0, 13),
  any.listWithLength(12, any.entero(0, _letras.length)),
  (int largo, List<int> indices) =>
      indices.take(largo).map((i) => _letras[i]).join(),
);

/// Un `numeric` como lo entrega PostgREST: `12.5`, `12` (int, columna sin
/// escala) o `12.0` (columna `numeric(12,2)` con `12.00`).
Generator<Object?> _numeric({bool conSigno = false}) => any.combine3(
      any.entero(0, 100000000),
      any.entero(0, 3),
      any.bool,
      (int centavos, int forma, bool negativo) {
        final c = conSigno && negativo ? -centavos : centavos;
        return switch (forma) {
          0 => c / 100,
          1 => c ~/ 100,
          _ => (c ~/ 100).toDouble(),
        };
      },
    );

class _Fecha {
  _Fecha(this.instante, this.forma);

  final DateTime instante;

  /// 0: `toIso8601String` (lo que escribe la app), 1: `Y-m-d H:i:s` (filas
  /// del viejo PHP), 2: solo el día (columnas `date`).
  final int forma;

  static String _dos(int n) => n.toString().padLeft(2, '0');

  String get _dia => '${instante.year.toString().padLeft(4, '0')}-'
      '${_dos(instante.month)}-${_dos(instante.day)}';

  String get texto => switch (forma) {
        0 => instante.toIso8601String(),
        1 => '$_dia ${_dos(instante.hour)}:${_dos(instante.minute)}:'
            '${_dos(instante.second)}',
        _ => _dia,
      };

  DateTime get esperado => switch (forma) {
        0 => instante,
        1 => DateTime(instante.year, instante.month, instante.day,
            instante.hour, instante.minute, instante.second),
        _ => DateTime(instante.year, instante.month, instante.day),
      };

  @override
  String toString() => texto;
}

Generator<_Fecha> _fecha({List<int> formas = const [0, 1, 2]}) => any.combine9(
      any.entero(2000, 2101),
      any.entero(1, 13),
      any.entero(1, 32),
      any.entero(0, 24),
      any.entero(0, 60),
      any.entero(0, 60),
      any.entero(0, 1000),
      any.entero(0, 1000),
      any.choose(formas),
      (int anio, int mes, int dia, int hora, int minuto, int segundo, int ms,
          int us, int forma) {
        final diasDelMes = DateTime(anio, mes + 1, 0).day;
        final instante = DateTime(anio, mes,
            dia > diasDelMes ? diasDelMes : dia, hora, minuto, segundo, ms, us);
        return _Fecha(instante, forma);
      },
    );

void _mismaFecha(DateTime actual, DateTime esperado) {
  expect(
    [
      actual.year,
      actual.month,
      actual.day,
      actual.hour,
      actual.minute,
      actual.second,
      actual.millisecond,
      actual.microsecond,
    ],
    [
      esperado.year,
      esperado.month,
      esperado.day,
      esperado.hour,
      esperado.minute,
      esperado.second,
      esperado.millisecond,
      esperado.microsecond,
    ],
    reason: '$actual vs $esperado',
  );
}

// --- Filas (columnas de supabase/migrations/20260925000000_prod_schema.sql) -

final _filaTela = any.combine10(
  _id,
  _texto,
  _numeric(),
  _numeric(),
  _numeric(),
  _numeric(),
  _nullable(_id), // categoria_id
  _nullable(_texto), // slug
  _nullable(_numeric()), // ancho
  any.bool,
  (int id,
          Object? nombre,
          Object? men,
          Object? may,
          Object? rollo,
          Object? compra,
          Object? categoria,
          Object? slug,
          Object? ancho,
          bool activo) =>
      _fila({
    'id': id,
    'nombre': nombre,
    'precxmen': men,
    'precxmay': may,
    'precxrollo': rollo,
    'precxcompra': compra,
    'categoria_id': categoria,
    'slug': slug,
    'descripcion': slug,
    'ancho': ancho,
    'activo': activo,
  }),
);

final _filaSucursal = any.combine5(
  _id,
  _texto,
  _nullable(_texto), // slug, direccion
  _nullable(_texto), // latitud, longitud
  any.bool,
  (int id, Object? nombre, Object? slug, Object? coordenada, bool activo) =>
      _fila({
    'id': id,
    'nombre': nombre,
    'slug': slug,
    'direccion': slug,
    'latitud': coordenada,
    'longitud': coordenada,
    'activo': activo,
  }),
);

final _filaTelaSucursal = any.combine3(
  _id,
  _texto,
  any.listWithLengthInRange(0, 4, any.bool),
  (int id, Object? nombre, List<bool> vinculos) => _fila({
    'id': id,
    'nombre': nombre,
    'tela_sucursales': [
      for (final activo in vinculos) {'activo': activo}
    ],
  }),
);

final _filaAplique = any.combine8(
  _id,
  _texto,
  _numeric(),
  _nullable(_id), // categoria_id
  any.bool,
  _nullable(_texto), // tamanio
  _nullable(_numeric()), // ancho_cm
  _nullable(_numeric()), // alto_cm
  (int id, Object? nombre, Object? costo, Object? categoria, bool activo,
          Object? tamanio, Object? ancho, Object? alto) =>
      _fila({
    'id': id,
    'nombre': nombre,
    'costo_fabricacion': costo,
    'categoria_id': categoria,
    'activo': activo,
    'tamanio': tamanio,
    'ancho_cm': ancho,
    'alto_cm': alto,
  }),
);

// select('aplique_id, color_id, stock, colores(nombre, hex)')
final _filaStock = any.combine5(
  _id,
  _id,
  _numeric(),
  _texto,
  any.either<Object?>(any.always<Object?>(null), _texto), // colores.hex
  (int aplique, int color, Object? stock, Object? nombre, Object? hex) =>
      _fila({
    'aplique_id': aplique,
    'color_id': color,
    'stock': stock,
    'colores': {'nombre': nombre, 'hex': hex},
  }),
);

// select('id, cantidad, apliques(nombre), colores(nombre, hex),
//         producciones(fecha, sucursales(nombre))')
final _filaDetalleProduccion = any.combine7(
  _id,
  _numeric(),
  _texto,
  _texto,
  any.either<Object?>(any.always<Object?>(null), _texto), // colores.hex
  _fecha(formas: const [2]),
  _texto,
  (int id, Object? cantidad, Object? aplique, Object? color, Object? hex,
          _Fecha fecha, Object? sucursal) =>
      _fila({
    'id': id,
    'cantidad': cantidad,
    'apliques': {'nombre': aplique},
    'colores': {'nombre': color, 'hex': hex},
    'producciones': {
      'fecha': fecha.texto,
      'sucursales': {'nombre': sucursal},
    },
  }),
);

final _filaProduccion = any.combine3(
  _id,
  _fecha(formas: const [2]),
  _id,
  (int id, _Fecha fecha, int sucursal) => (
    _fila({'id': id, 'fecha': fecha.texto, 'sucursal_id': sucursal}),
    fecha,
  ),
);

// ventas y ventas_apliques tienen la misma forma
final _filaVenta = any.combine6(
  _id,
  _fecha(),
  _numeric(),
  _numeric(conSigno: true),
  _numeric(),
  _id,
  (int id, _Fecha fecha, Object? total, Object? ganancias, Object? descuento,
          int sucursal) =>
      (
    _fila({
      'id': id,
      'fecha': fecha.texto,
      'total': total,
      'ganancias': ganancias,
      'descuento': descuento,
      'idsucursales': sucursal,
    }),
    fecha,
  ),
);

final _filaDetalleVentaAplique = any.combine9(
  _id,
  _id,
  _id,
  _id,
  _nullable(_texto), // nombre
  _numeric(),
  _numeric(),
  _numeric(),
  _numeric(conSigno: true),
  (int id, int venta, int aplique, int color, Object? nombre, Object? precio,
          Object? cantidad, Object? total, Object? ganancias) =>
      _fila({
    'id': id,
    'idventa': venta,
    'idapliques': aplique,
    'idcolor': color,
    'nombre': nombre,
    'precio': precio,
    'cantidad': cantidad,
    'total': total,
    'ganancias': ganancias,
  }),
);

final _filaDetalleVenta = any.combine8(
  _id,
  _nullable(_texto), // nombre
  _numeric(),
  _numeric(),
  _nullable(_numeric()), // total
  _nullable(_numeric(conSigno: true)), // ganancias
  _id,
  _id,
  (int id, Object? nombre, Object? precio, Object? cantidad, Object? total,
          Object? ganancias, int tela, int venta) =>
      _fila({
    'id': id,
    'nombre': nombre,
    'precio': precio,
    'cantidad': cantidad,
    'total': total,
    'ganancias': ganancias,
    'idtelas': tela,
    'idventa': venta,
  }),
);
