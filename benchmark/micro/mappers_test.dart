@Tags(['benchmark'])
library;

// Micro-benchmarks de los mappers (JSON de Supabase -> entidad).
//
// Las filas tienen la forma real de lo que devuelve cada `select` de los
// datasources (columnas de supabase/migrations/ y joins embebidos) y pasan
// por jsonEncode/jsonDecode para llegar con los mismos tipos que entrega
// PostgREST (int o double según el valor, mapas y listas anidadas). Se mide
// una fila y listas de 100 y 1000 filas mapeadas como en los datasources:
// `list.map<T>((e) => Mapper.jsonToEntity(e)).toList()`.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/aplique_mapper.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/produccion_mapper.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/stock_aplique_mapper.dart';
import 'package:textiles_app/features/apliques/infrastructure/mappers/venta_aplique_mapper.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/infrastructure/mappers/sucursal_mapper.dart';
import 'package:textiles_app/features/sucursales/infrastructure/mappers/tela_sucursal_mapper.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/infrastructure/mappers/tela_mapper.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/infrastructure/mappers/detalleVenta_mapper.dart';
import 'package:textiles_app/features/ventas/infrastructure/mappers/venta_mapper.dart';

import 'medicion.dart';

/// Último resultado medido: que el compilador no pueda descartar el trabajo.
Object? sink;

/// Presupuestos (µs/op) de 1 fila y de listas de 100 y 1000 filas.
typedef Presupuestos = ({double x1, double x100, double x1000});

void main() {
  grupoBenchmark('mappers', () {
    _mapper<Tela>(
      'TelaMapper.jsonToEntity',
      _filaTela,
      (e) => TelaMapper.jsonToEntity(e),
      (x1: 3, x100: 700, x1000: 5000),
      verificar: (t) => t.nombre == 'Tela 0' && t.precxmen == 35,
    );
    _mapper<Sucursal>(
      'SucursalMapper.jsonToEntity',
      _filaSucursal,
      (e) => SucursalMapper.jsonToEntity(e),
      (x1: 1, x100: 150, x1000: 1500),
      verificar: (s) => s.nombre == 'Sucursal 0',
    );
    _mapper<TelaSucursal>(
      'TelaSucursalMapper.jsonToEntity',
      _filaTelaSucursal,
      (e) => TelaSucursalMapper.jsonToEntity(e),
      (x1: 2, x100: 200, x1000: 1500),
      verificar: (t) => t.idtela == 1 && t.disponible,
    );
    _mapper<Aplique>(
      'ApliqueMapper.jsonToEntity',
      _filaAplique,
      (e) => ApliqueMapper.jsonToEntity(e),
      (x1: 3, x100: 300, x1000: 7000),
      verificar: (a) => a.nombre == 'Aplique 0 10x8' && a.anchoCm == 10,
    );
    _mapper<StockAplique>(
      'StockApliqueMapper.jsonToEntity',
      _filaInventario,
      (e) => StockApliqueMapper.jsonToEntity(e),
      (x1: 5, x100: 500, x1000: 7000),
      verificar: (s) => s.colorNombre == 'Color 0' && s.hex == '#0000FF',
    );
    _mapper<Produccion>(
      'ProduccionMapper.jsonToEntity',
      _filaDetalleProduccion,
      (e) => ProduccionMapper.jsonToEntity(e),
      (x1: 10, x100: 700, x1000: 30000),
      verificar: (p) => p.sucursalNombre == 'Centro' && p.fecha == '2026-10-01',
    );
    _mapper<ProduccionCabecera>(
      'ProduccionMapper.jsonToCabecera',
      _filaProduccion,
      (e) => ProduccionMapper.jsonToCabecera(e),
      // Los tres mappers con fecha cuestan ~150x más que el resto: armar el
      // DateTime local consulta la zona horaria del sistema (lento en
      // Windows) y varía mucho entre corridas. Los listados piden
      // `.limit(10)`, así que hoy no se nota.
      (x1: 1500, x100: 200000, x1000: 1000000),
      verificar: (p) => p.fecha == DateTime(2026, 10, 1),
    );
    _mapper<VentaAplique>(
      'VentaApliqueMapper.jsonToVentaAplique',
      _filaVenta,
      (e) => VentaApliqueMapper.jsonToVentaAplique(e),
      (x1: 700, x100: 70000, x1000: 700000),
      verificar: (v) => v.fecha.year == 2026 && v.fecha.month == 10,
    );
    _mapper<DetalleVentaAplique>(
      'VentaApliqueMapper.jsonToDetalle',
      _filaDetalleVentaAplique,
      (e) => VentaApliqueMapper.jsonToDetalle(e),
      (x1: 2, x100: 300, x1000: 3000),
      verificar: (d) => d.nombre == 'Aplique 0 10x8' && d.cantidad == 1,
    );
    _mapper<Venta>(
      'VentaMapper.jsonToEntity',
      _filaVenta,
      (e) => VentaMapper.jsonToEntity(e),
      (x1: 1000, x100: 150000, x1000: 500000),
      verificar: (v) => v.fecha.year == 2026 && v.idsucursales == 1,
    );
    _mapper<DetalleVenta>(
      'DetalleVentaMapper.jsonToEntity',
      _filaDetalleVenta,
      (e) => DetalleVentaMapper.jsonToEntity(e),
      (x1: 2, x100: 300, x1000: 3000),
      verificar: (d) => d.nombre == 'Tela 0' && d.precio == 35,
    );
  });
}

/// Registra tres benchmarks de [mapear]: una fila y listas de 100 y 1000.
/// [verificar] se aplica a la primera entidad (fuera de la medición) para
/// asegurar que las filas tienen la forma que espera el mapper.
void _mapper<T>(
  String nombre,
  Map<String, Object?> Function(int i) fila,
  T Function(Map<String, dynamic>) mapear,
  Presupuestos presupuestos, {
  required bool Function(T primera) verificar,
}) {
  final filas = _comoSupabase([for (var i = 0; i < 1000; i++) fila(i)]);
  final una = filas.first;
  final cien = filas.sublist(0, 100);

  void comprobar(List<T> lista, int largo) {
    expect(lista, hasLength(largo));
    expect(verificar(lista.first), isTrue, reason: '$nombre: fila inesperada');
  }

  microBenchmark(
    '$nombre x1',
    () => sink = mapear(una),
    presupuestoUs: presupuestos.x1,
    preparar: () => comprobar([mapear(una)], 1),
  );
  microBenchmark(
    '$nombre x100',
    () => sink = cien.map<T>(mapear).toList(),
    presupuestoUs: presupuestos.x100,
    preparar: () => comprobar(cien.map<T>(mapear).toList(), 100),
  );
  microBenchmark(
    '$nombre x1000',
    () => sink = filas.map<T>(mapear).toList(),
    presupuestoUs: presupuestos.x1000,
    preparar: () => comprobar(filas.map<T>(mapear).toList(), 1000),
  );
}

/// Las filas como las entrega supabase_flutter: pasadas por JSON y en una
/// `List<Map<String, dynamic>>`.
List<Map<String, dynamic>> _comoSupabase(List<Map<String, Object?>> filas) =>
    List<Map<String, dynamic>>.from(jsonDecode(jsonEncode(filas)) as List);

/// NUMERIC(12,2): PostgREST lo manda como entero si no tiene decimales.
num _plata(int i, num base) => i % 3 == 0 ? base + i : base + i + 0.5;

/// `fecha` de ventas y ventas_apliques: TEXT ISO8601 de `toIso8601String()`.
String _fechaIso(int i) =>
    DateTime(2026, 10, 1 + i % 28, 9 + i % 10, i % 60, i % 60, i % 1000, 500)
        .toIso8601String();

// telas: select() (getTelas) — todas las columnas.
Map<String, Object?> _filaTela(int i) => {
      'id': i + 1,
      'nombre': 'Tela $i',
      'precxmen': _plata(i, 35),
      'precxmay': _plata(i, 30),
      'precxrollo': _plata(i, 25),
      'precxcompra': _plata(i, 18),
      'categoria_id': 1,
      'slug': 'tela-$i',
      'descripcion': 'Descripción de la tela $i para el catálogo web',
      'ancho': 1.5,
      'activo': true,
    };

// sucursales: select() (getSucursales).
Map<String, Object?> _filaSucursal(int i) => {
      'id': i + 1,
      'nombre': 'Sucursal $i',
      'slug': 'sucursal-$i',
      'latitud': '-17.78${i % 10}',
      'longitud': '-63.18${i % 10}',
      'direccion': 'Calle $i #${100 + i}',
      'activo': true,
    };

// telas: select('id, nombre, tela_sucursales(activo)') (getTelasSucursal).
// El embed viene vacío si la tela nunca se vinculó a la sucursal.
Map<String, Object?> _filaTelaSucursal(int i) => {
      'id': i + 1,
      'nombre': 'Tela $i',
      'tela_sucursales': switch (i % 3) {
        0 => [
            {'activo': true}
          ],
        1 => [
            {'activo': false}
          ],
        _ => <Object?>[],
      },
    };

// apliques: select() (getApliques).
Map<String, Object?> _filaAplique(int i) => {
      'id': i + 1,
      'nombre': 'Aplique $i 10x8',
      'costo_fabricacion': _plata(i, 4),
      'categoria_id': 2,
      'activo': true,
      'tamanio': null,
      'ancho_cm': 10,
      'alto_cm': 8.5,
    };

// inventario: select('aplique_id, color_id, stock, colores(nombre, hex)')
// (getStock).
Map<String, Object?> _filaInventario(int i) => {
      'aplique_id': i ~/ 10 + 1,
      'color_id': i % 10 + 1,
      'stock': i % 4 == 0 ? 0 : i % 50,
      'colores': {
        'nombre': 'Color ${i % 10}',
        'hex':
            '#${(255 - i % 256).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      },
    };

// detalle_produccion: select('id, cantidad, apliques(nombre),
// colores(nombre, hex), producciones(fecha, sucursales(nombre))')
// (getDetalleProduccion).
Map<String, Object?> _filaDetalleProduccion(int i) => {
      'id': 1000 - i,
      'cantidad': 1 + i % 20,
      'apliques': {'nombre': 'Aplique $i 10x8'},
      'colores': {'nombre': 'Color ${i % 10}', 'hex': '#FF8800'},
      'producciones': {
        'fecha': '2026-10-01',
        'sucursales': {'nombre': 'Centro'},
      },
    };

// producciones: select() (getProducciones). `fecha` es DATE.
Map<String, Object?> _filaProduccion(int i) => {
      'id': i + 1,
      'fecha': '2026-10-${(1 + i % 28).toString().padLeft(2, '0')}',
      'sucursal_id': 1,
    };

// ventas y ventas_apliques: select() (misma forma).
Map<String, Object?> _filaVenta(int i) => {
      'id': i + 1,
      'fecha': _fechaIso(i),
      'total': _plata(i, 350),
      'ganancias': _plata(i, 120),
      'descuento': i % 5 == 0 ? 10 : 0,
      'idsucursales': 1 + i % 3,
    };

// detalle_ventas_apliques: select() (getDetalleVentaAplique).
Map<String, Object?> _filaDetalleVentaAplique(int i) => {
      'id': i + 1,
      'idventa': 1,
      'idapliques': i + 1,
      'idcolor': 1 + i % 10,
      'nombre': 'Aplique $i 10x8',
      'precio': _plata(i, 12),
      'cantidad': 1 + i % 6,
      'total': _plata(i, 24),
      'ganancias': _plata(i, 8),
    };

// detalle_ventas: select() (getDetalleVentas).
Map<String, Object?> _filaDetalleVenta(int i) => {
      'id': i + 1,
      'nombre': 'Tela $i',
      'precio': _plata(i, 35),
      'cantidad': i % 2 == 0 ? 2 : 1.5,
      'total': _plata(i, 70),
      'ganancias': _plata(i, 20),
      'idtelas': i + 1,
      'idventa': 1,
    };
