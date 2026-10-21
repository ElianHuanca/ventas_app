// Micro-benchmarks de los blocs de listados: desde el evento de carga hasta
// el estado cargado (isLoading en false) en el stream, con listas de
// 10/100/1000 ítems de los fakes en memoria (test/helpers/).
//
//   flutter test benchmark/micro/blocs_test.dart
//
// Cada bloc se crea una vez (su constructor ya dispara la primera carga) y
// cada iteración es una recarga completa: mismo trabajo en todas.
@Tags(['benchmark'])
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';

import '../../test/helpers/fake_repositories.dart';
import 'medicion.dart';

const _tamanos = [10, 100, 1000];

final _fecha = DateTime(2026, 10, 11);

// ---------------------------------------------------------------- datos

List<Tela> _telas(int n) => [
      for (var i = 1; i <= n; i++)
        Tela(
          id: i,
          nombre: 'Tela $i',
          precxmen: 12.5,
          precxmay: 10,
          precxrollo: 350,
          precxcompra: 6,
          activo: i % 10 != 0,
        ),
    ];

List<Sucursal> _sucursales(int n) =>
    [for (var i = 1; i <= n; i++) Sucursal(id: i, nombre: 'Sucursal $i')];

List<Aplique> _apliques(int n) => [
      for (var i = 1; i <= n; i++)
        Aplique(
          id: i,
          nombre: 'Flor $i - Bolsa x100 und',
          costoFabricacion: 2.5,
          anchoCm: 4,
          altoCm: 4,
          activo: i % 10 != 0,
        ),
    ];

List<StockAplique> _stock(int n) => [
      for (var i = 1; i <= n; i++)
        StockAplique(
          apliqueId: i,
          colorId: i % 5 + 1,
          colorNombre: 'Color ${i % 5 + 1}',
          hex: 'A0B0C0',
          stock: 10,
        ),
    ];

List<ColorItem> _colores(int n) => [
      for (var i = 1; i <= n; i++)
        ColorItem(id: i, nombre: 'Color $i', hex: 'FF0000'),
    ];

List<Venta> _ventas(int n) => [
      for (var i = 1; i <= n; i++)
        Venta(
          id: i,
          fecha: _fecha.subtract(Duration(days: i)),
          total: 100.0 + i,
          ganancias: 20,
          descuento: 0,
          idsucursales: 1,
        ),
    ];

List<VentaAplique> _ventasApliques(int n) => [
      for (var i = 1; i <= n; i++)
        VentaAplique(id: i, fecha: _fecha.subtract(Duration(days: i))),
    ];

List<ProduccionCabecera> _producciones(int n) => [
      for (var i = 1; i <= n; i++)
        ProduccionCabecera(id: i, fecha: _fecha.subtract(Duration(days: i))),
    ];

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

// ------------------------------------------------------------- medición

/// Registra un benchmark de recarga: [crear] arma el bloc (que se carga
/// solo), [recargar] le manda el evento y se espera en el stream al primer
/// estado con [cargado]. [largo] verifica que la lista cargada tiene [n].
void _benchRecarga<B extends BlocBase<S>, S>(
  String nombre,
  int n, {
  required B Function() crear,
  required void Function(B bloc) recargar,
  required bool Function(S estado) cargado,
  required int Function(S estado) largo,
}) {
  late B bloc;
  microBenchmarkAsync(
    nombre,
    () async {
      final listo = bloc.stream.firstWhere(cargado);
      recargar(bloc);
      await listo;
    },
    presupuestoUs: _presupuesto(nombre),
    preparar: () async {
      bloc = crear();
      addTearDown(bloc.close);
      await bloc.stream.firstWhere(cargado);
      expect(largo(bloc.state), n);
    },
  );
}

/// Presupuesto (µs/op) de [nombre] en la tabla del final del archivo.
double _presupuesto(String nombre) =>
    _presupuestos[nombre] ??
    (throw ArgumentError('Falta el presupuesto de "$nombre"'));

void main() {
  grupoBenchmark('blocs', () {
    for (final n in _tamanos) {
      _benchRecarga<TelasBloc, TelasState>(
        'TelasBloc cargar $n telas',
        n,
        crear: () =>
            TelasBloc(telasRepository: FakeTelasRepository(telas: _telas(n))),
        recargar: (b) => b.add(TelasLoadRequested()),
        cargado: (s) => !s.isLoading,
        largo: (s) => s.telas.length,
      );
    }

    for (final n in _tamanos) {
      _benchRecarga<SucursalesBloc, SucursalesState>(
        'SucursalesBloc cargar $n sucursales',
        n,
        crear: () => SucursalesBloc(
          sucursalesRepository:
              FakeSucursalesRepository(sucursales: _sucursales(n)),
        ),
        recargar: (b) => b.add(SucursalesLoadRequested()),
        cargado: (s) => !s.isLoading,
        largo: (s) => s.sucursales.length,
      );
    }

    for (final n in _tamanos) {
      _benchRecarga<ApliquesBloc, ApliquesState>(
        'ApliquesBloc cargar $n apliques (gestión)',
        n,
        crear: () => ApliquesBloc(
          apliquesRepository: FakeApliquesRepository(apliques: _apliques(n)),
        ),
        recargar: (b) => b.add(ApliquesLoadRequested()),
        cargado: (s) => !s.isLoading,
        largo: (s) => s.apliques.length,
      );
    }

    for (final n in _tamanos) {
      _benchRecarga<ApliquesBloc, ApliquesState>(
        'ApliquesBloc cargar $n apliques + stock (venta en sucursal)',
        n,
        crear: () => ApliquesBloc(
          apliquesRepository: FakeApliquesRepository(
            apliques: _apliques(n),
            stock: _stock(n),
          ),
          idsucursal: 1,
        ),
        recargar: (b) => b.add(ApliquesLoadRequested()),
        cargado: (s) => !s.isLoading,
        largo: (s) => s.stock.length,
      );
    }

    for (final n in _tamanos) {
      _benchRecarga<ColoresBloc, ColoresState>(
        'ColoresBloc cargar $n colores',
        n,
        crear: () => ColoresBloc(
          coloresRepository: FakeColoresRepository(colores: _colores(n)),
        ),
        recargar: (b) => b.add(ColoresLoadRequested()),
        cargado: (s) => !s.isLoading,
        largo: (s) => s.colores.length,
      );
    }

    for (final n in _tamanos) {
      _benchRecarga<VentasBloc, VentasState>(
        'VentasBloc cargar $n ventas',
        n,
        crear: () => VentasBloc(
          ventasRepository: FakeVentasRepository(ventas: _ventas(n)),
          idsucursal: 1,
        ),
        recargar: (b) => b.add(VentasLoadRequested(1)),
        cargado: (s) => !s.isLoading,
        largo: (s) => s.ventas.length,
      );
    }

    for (final n in _tamanos) {
      _benchRecarga<VentasApliquesBloc, VentasApliquesState>(
        'VentasApliquesBloc cargar $n ventas',
        n,
        crear: () => VentasApliquesBloc(
          ventasApliquesRepository:
              FakeVentasApliquesRepository(ventas: _ventasApliques(n)),
          idsucursal: 1,
        ),
        recargar: (b) => b.add(VentasApliquesLoadRequested(1)),
        cargado: (s) => !s.isLoading,
        largo: (s) => s.ventas.length,
      );
    }

    for (final n in _tamanos) {
      _benchRecarga<ProduccionesBloc, ProduccionesState>(
        'ProduccionesBloc cargar $n producciones',
        n,
        crear: () => ProduccionesBloc(
          apliquesRepository:
              FakeApliquesRepository(producciones: _producciones(n)),
          idsucursal: 1,
        ),
        recargar: (b) => b.add(ProduccionesLoadRequested(1)),
        cargado: (s) => !s.isLoading,
        largo: (s) => s.producciones.length,
      );
    }

    for (final n in _tamanos) {
      // Su estado inicial ya es isLoading: true y la recarga no lo vuelve a
      // poner en true: el primer estado nuevo ya es el cargado.
      _benchRecarga<DetalleVentasBloc, DetalleVentasState>(
        'DetalleVentasBloc cargar $n líneas',
        n,
        crear: () => DetalleVentasBloc(
          detalleVentasRepository:
              FakeDetalleVentasRepository(detalles: _detalleVentas(n)),
          ventaActualizada: (_) {},
          idventa: 1,
        ),
        recargar: (b) => b.add(DetalleVentasLoadRequested()),
        cargado: (s) => !s.isLoading,
        largo: (s) => s.detalleVentas.length,
      );
    }

    // Editar reemplaza la tela en la lista con un map: O(n) por edición.
    for (final n in _tamanos) {
      late TelasBloc bloc;
      final cambio = {'id': n ~/ 2, 'nombre': 'Tela editada'};
      final nombre = 'TelasBloc actualizar 1 tela (listado de $n)';
      microBenchmarkAsync(
        nombre,
        () async {
          final listo = bloc.stream.first;
          await bloc.updateTela(cambio);
          await listo;
        },
        presupuestoUs: _presupuesto(nombre),
        preparar: () async {
          bloc = TelasBloc(
            telasRepository: FakeTelasRepository(telas: _telas(n)),
          );
          addTearDown(bloc.close);
          await bloc.stream.firstWhere((s) => !s.isLoading);
          final listo = bloc.stream.first;
          expect(await bloc.updateTela(cambio), isTrue);
          await listo;
          expect(bloc.state.telas, hasLength(n));
          expect(
            bloc.state.telas.firstWhere((t) => t.id == n ~/ 2).nombre,
            'Tela editada',
          );
        },
      );
    }
  });
}

/// Presupuestos (µs/op): ~10x el peor valor de 3 corridas seguidas de
/// `flutter test benchmark/micro` (JIT, Windows, 2026-10-11), redondeado hacia
/// arriba a 2 cifras. Al agregar un benchmark, agregar su fila (si falta, el
/// archivo no carga); al cambiar de máquina de referencia, recalibrar.
const _presupuestos = <String, double>{
  'TelasBloc cargar 10 telas': 8000,
  'TelasBloc cargar 100 telas': 2500,
  'TelasBloc cargar 1000 telas': 2000,
  'SucursalesBloc cargar 10 sucursales': 1700,
  'SucursalesBloc cargar 100 sucursales': 1800,
  'SucursalesBloc cargar 1000 sucursales': 1900,
  'ApliquesBloc cargar 10 apliques (gestión)': 2100,
  'ApliquesBloc cargar 100 apliques (gestión)': 2500,
  'ApliquesBloc cargar 1000 apliques (gestión)': 1900,
  'ApliquesBloc cargar 10 apliques + stock (venta en sucursal)': 2000,
  'ApliquesBloc cargar 100 apliques + stock (venta en sucursal)': 2300,
  'ApliquesBloc cargar 1000 apliques + stock (venta en sucursal)': 2100,
  'ColoresBloc cargar 10 colores': 5700,
  'ColoresBloc cargar 100 colores': 4000,
  'ColoresBloc cargar 1000 colores': 3100,
  'VentasBloc cargar 10 ventas': 5100,
  'VentasBloc cargar 100 ventas': 3200,
  'VentasBloc cargar 1000 ventas': 6200,
  'VentasApliquesBloc cargar 10 ventas': 2700,
  'VentasApliquesBloc cargar 100 ventas': 3000,
  'VentasApliquesBloc cargar 1000 ventas': 2200,
  'ProduccionesBloc cargar 10 producciones': 1500,
  'ProduccionesBloc cargar 100 producciones': 1600,
  'ProduccionesBloc cargar 1000 producciones': 1700,
  'DetalleVentasBloc cargar 10 líneas': 2100,
  'DetalleVentasBloc cargar 100 líneas': 1700,
  'DetalleVentasBloc cargar 1000 líneas': 2900,
  'TelasBloc actualizar 1 tela (listado de 10)': 3200,
  'TelasBloc actualizar 1 tela (listado de 100)': 1900,
  'TelasBloc actualizar 1 tela (listado de 1000)': 2500,
};
