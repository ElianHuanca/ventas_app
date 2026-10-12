// Micro-benchmarks de las tablas y listas compartidas: ms por montaje desde
// cero (build + layout + paint) con 10/100/500 filas.
//
//   flutter test benchmark/micro/widgets/tablas_test.dart
//
// Se montan como en las pantallas: único hijo del ListView de Screen1. Un
// DataTable (y una Column) no es perezoso: arma y mide todas sus filas
// aunque no entren en pantalla.
@Tags(['benchmark'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/config/theme/app_theme.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/widgets/data_table_apliques.dart';
import 'package:textiles_app/features/apliques/presentation/widgets/data_table_produccion.dart';
import 'package:textiles_app/features/shared/widgets/data_table_telas.dart';
import 'package:textiles_app/features/shared/widgets/data_table_widget.dart';
import 'package:textiles_app/features/shared/widgets/producto_colores_list.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';

import '../medicion.dart';

final _tema = AppTheme().getTheme();

/// Como Screen1: Scaffold con un ListView cuyo único hijo es [hijo].
Widget _enPantalla(Widget hijo) => MaterialApp(
      theme: _tema,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ListView(shrinkWrap: true, children: [hijo]),
      ),
    );

/// Filas y repeticiones de cada tabla: las grandes tardan más y con menos
/// vueltas alcanza.
const _casos = [(10, 20), (100, 10), (500, 5)];

/// [widgetBenchmark] con el presupuesto de [_presupuestos].
void _widget(
  String nombre,
  Widget Function() construir, {
  int repeticiones = 20,
}) =>
    widgetBenchmark(
      nombre,
      construir,
      presupuestoMs: _presupuestos[nombre] ??
          (throw ArgumentError('Falta el presupuesto de "$nombre"')),
      repeticiones: repeticiones,
    );

// ---------------------------------------------------------------- datos

/// Carrito de DetVenta (DetalleVentaFormCubit.detVentas).
List<Map<String, dynamic>> _carritoTelas(int n) => [
      for (var i = 1; i <= n; i++)
        {
          'idtelas': i,
          'nombre': 'Tela $i',
          'cantidad': 3.0,
          'precio': 12.5,
          'total': 37.5,
          'ganancias': 19.5,
        },
    ];

/// Líneas guardadas de una venta (DetVentas).
List<DetalleVenta> _detalleVentas(int n) => [
      for (var i = 1; i <= n; i++)
        DetalleVenta(
          id: i,
          nombre: 'Tela $i',
          precio: 12.5,
          cantidad: 3,
          total: 37.5,
          ganancias: 19.5,
          idtelas: i,
        ),
    ];

/// Carrito de VentaApliquesScreen (VentaApliquesFormCubit.detalles).
List<Map<String, dynamic>> _carritoApliques(int n) => [
      for (var i = 0; i < n; i++)
        {
          'idapliques': i ~/ 5 + 1,
          'idcolor': i % 5 + 1,
          'nombre': 'Flor ${i ~/ 5 + 1} (Color ${i % 5 + 1})',
          'cantidad': 2.0,
          'precio': 8.0,
          'total': 16.0,
          'ganancias': 11.0,
        },
    ];

/// Listado de ProduccionScreen (ProduccionFormCubit.detProducciones).
List<Map<String, dynamic>> _lineasProduccion(int n) => [
      for (var i = 0; i < n; i++)
        {
          'idaplique': i ~/ 5 + 1,
          'apliqueNombre': 'Flor ${i ~/ 5 + 1}',
          'idcolor': i % 5 + 1,
          'colorNombre': 'Color ${i % 5 + 1}',
          'hex': 'A0B0C${i % 5}',
          'cantidad': 4.0,
        },
    ];

List<ColorItem> _colores(int n) => [
      for (var i = 1; i <= n; i++)
        ColorItem(
          id: i,
          nombre: 'Color $i',
          hex: 'FF${(i % 100).toString().padLeft(2, '0')}00',
          vinculado: i.isEven,
        ),
    ];

void main() {
  grupoBenchmark('widgets_tablas', () {
    // Calienta el JIT para que el primer benchmark no pague la compilación
    // del framework (widgetBenchmark solo hace un montaje de warmup).
    testWidgets('calentamiento (no se mide)', (tester) async {
      final filas = _carritoTelas(20);
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(_enPantalla(DataTableMapTelas(
          listheader: const ['Nombre', 'Cantidad', 'Precio', 'Total', ''],
          listbody: filas,
          total: 0,
          onTap: (_, __, ___) {},
        )));
        await tester.pumpWidget(const SizedBox());
      }
    });

    // Lo que cuesta el andamiaje solo: restarlo para ver el de cada tabla.
    _widget(
      'Base: MaterialApp + Scaffold + ListView vacío',
      () => _enPantalla(const SizedBox(height: 10)),
    );

    for (final (n, repeticiones) in _casos) {
      final filas = _carritoTelas(n);
      _widget(
        'DataTableMapTelas montar $n filas (carrito de DetVenta)',
        () => _enPantalla(DataTableMapTelas(
          listheader: const ['Nombre', 'Cantidad', 'Precio', 'Total', ''],
          listbody: filas,
          total: 37.5 * n,
          onTap: (_, __, ___) {},
        )),
        repeticiones: repeticiones,
      );
    }

    for (final (n, repeticiones) in _casos) {
      final lineas = _detalleVentas(n);
      _widget(
        'dataTableWidget montar $n filas (detalle de venta)',
        () => _enPantalla(Builder(
          builder: (context) => dataTableWidget(
            const ['Nombre', 'Cantidad', 'Precio', 'Total', ''],
            context,
            lineas,
            37.5 * n,
            19.5 * n,
            0,
            (_) {},
          ),
        )),
        repeticiones: repeticiones,
      );
    }

    for (final (n, repeticiones) in _casos) {
      final filas = _carritoApliques(n);
      _widget(
        'DataTableApliques montar $n filas (carrito de venta de apliques)',
        () => _enPantalla(DataTableApliques(
          listbody: filas,
          total: 16.0 * n,
          onTap: (_, __, ___, ____) {},
        )),
        repeticiones: repeticiones,
      );
    }

    for (final (n, repeticiones) in _casos) {
      final filas = _lineasProduccion(n);
      _widget(
        'DataTableProduccion montar $n filas (con color)',
        () => _enPantalla(DataTableProduccion(
          listbody: filas,
          onTap: (_, __, ___) {},
        )),
        repeticiones: repeticiones,
      );
    }

    for (final n in [10, 50]) {
      final colores = _colores(n);
      _widget(
        'ProductoColoresList montar $n colores',
        () => _enPantalla(ProductoColoresList(
          isLoading: false,
          colores: colores,
          onToggle: (_, __) {},
        )),
      );
    }
  });
}

/// Presupuestos (ms/montaje): ~10x el peor valor de 3 corridas seguidas de
/// `flutter test benchmark/micro` (JIT, Windows, 2026-10-11), redondeado hacia
/// arriba a 2 cifras. Al agregar un benchmark, agregar su fila (si falta, el
/// archivo no carga); al cambiar de máquina de referencia, recalibrar.
const _presupuestos = <String, double>{
  'Base: MaterialApp + Scaffold + ListView vacío': 94,
  'DataTableMapTelas montar 10 filas (carrito de DetVenta)': 520,
  'DataTableMapTelas montar 100 filas (carrito de DetVenta)': 3000,
  'DataTableMapTelas montar 500 filas (carrito de DetVenta)': 17000,
  'dataTableWidget montar 10 filas (detalle de venta)': 470,
  'dataTableWidget montar 100 filas (detalle de venta)': 3100,
  'dataTableWidget montar 500 filas (detalle de venta)': 12000,
  'DataTableApliques montar 10 filas (carrito de venta de apliques)': 260,
  'DataTableApliques montar 100 filas (carrito de venta de apliques)': 2000,
  'DataTableApliques montar 500 filas (carrito de venta de apliques)': 17000,
  'DataTableProduccion montar 10 filas (con color)': 540,
  'DataTableProduccion montar 100 filas (con color)': 4900,
  'DataTableProduccion montar 500 filas (con color)': 19000,
  'ProductoColoresList montar 10 colores': 760,
  'ProductoColoresList montar 50 colores': 2000,
};
