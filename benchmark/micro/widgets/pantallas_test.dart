// Micro-benchmarks de las pantallas de listado más pesadas, montadas desde
// cero con su bloc ya cargado (fakes en memoria de test/helpers/).
//
//   flutter test benchmark/micro/widgets/pantallas_test.dart
//
// TelasScreen y ApliquesScreen usan el ListView de Screen1 (perezoso: solo
// arma las tarjetas visibles). El ranking del dashboard y la tabla del
// carrito de DetVenta van en un solo hijo del ListView: se arman enteros.
@Tags(['benchmark'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/config/theme/app_theme.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:textiles_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/presentation/screens/screens.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/presentation/screens/screens.dart';

import '../../../test/helpers/fake_repositories.dart';
import '../medicion.dart';

final _tema = AppTheme().getTheme();

Widget _app(Widget pantalla) => MaterialApp(
      theme: _tema,
      debugShowCheckedModeBanner: false,
      home: pantalla,
    );

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

List<TopProducto> _ranking(int n, String prefijo) => [
      for (var i = 0; i < n; i++)
        TopProducto(
          nombre: '$prefijo ${i + 1}',
          totalVendido: (n - i) * 100.0,
          totalCantidad: ((i * 37) % n) + 1.5,
        ),
    ];

// ------------------------------------------------------- blocs cargados

Future<TelasBloc> _telasBloc(int n, {int? idsucursal}) async {
  final bloc = TelasBloc(
    telasRepository: FakeTelasRepository(telas: _telas(n)),
    idsucursal: idsucursal,
  );
  await bloc.stream.firstWhere((s) => !s.isLoading);
  return bloc;
}

Future<ApliquesBloc> _apliquesBloc(int n) async {
  final bloc = ApliquesBloc(
    apliquesRepository: FakeApliquesRepository(apliques: _apliques(n)),
  );
  await bloc.stream.firstWhere((s) => !s.isLoading);
  return bloc;
}

Future<DashboardCubit> _dashboard(int n) async {
  final cubit = DashboardCubit(
    repository: FakeDashboardRepository(
      topTelas: _ranking(n, 'Tela'),
      topApliques: _ranking(n, 'Aplique'),
      resumenTelas:
          const ResumenVentas(total: 12500, ganancias: 4100, descuento: 35),
      resumenApliques:
          const ResumenVentas(total: 3900, ganancias: 1700, descuento: 0),
    ),
  );
  await cubit.stream.firstWhere((s) => !s.isLoading);
  return cubit;
}

/// Carrito de DetVenta con [lineas] telas distintas, cargado por la API
/// pública del cubit (como al tocar Añadir).
DetalleVentaFormCubit _carrito(List<Tela> telas, int lineas) {
  final cubit = DetalleVentaFormCubit(
    ventasRepository: FakeVentasRepository(),
    detalleVentasRepository: FakeDetalleVentasRepository(),
    idsucursal: 1,
  );
  for (final tela in telas.take(lineas)) {
    cubit
      ..onPrecxCompraChanged(tela.precxcompra ?? 0)
      ..onNombreChanged(tela.nombre)
      ..onIdTelasChanged(tela.id)
      ..onPrecioChanged('12.5')
      ..onCantidadChanged('3')
      ..addDetalleVenta();
  }
  return cubit;
}

void main() {
  grupoBenchmark('widgets_pantallas', () {
    final abiertos = <BlocBase<Object?>>[];
    tearDownAll(() async {
      for (final b in abiertos) {
        await b.close();
      }
    });

    // Los blocs se cargan una vez (fuera de la medición) y cada montaje los
    // reusa con BlocProvider.value.
    late TelasBloc telas10, telas500, telasVenta50, telasVenta200;
    late ApliquesBloc apliques10, apliques500;
    late DashboardCubit dashboard10, dashboard100, dashboard200;
    late DetalleVentaFormCubit carritoVacio, carrito100;
    setUpAll(() async {
      abiertos.addAll([
        telas10 = await _telasBloc(10),
        telas500 = await _telasBloc(500),
        telasVenta50 = await _telasBloc(50, idsucursal: 1),
        telasVenta200 = await _telasBloc(200, idsucursal: 1),
        apliques10 = await _apliquesBloc(10),
        apliques500 = await _apliquesBloc(500),
        dashboard10 = await _dashboard(10),
        dashboard100 = await _dashboard(100),
        dashboard200 = await _dashboard(200),
        carritoVacio = _carrito(const [], 0),
        carrito100 = _carrito(_telas(100), 100),
      ]);
      expect(carrito100.state.detVentas, hasLength(100));
    });

    // Calienta el JIT para que el primer benchmark no pague la compilación
    // del framework (widgetBenchmark solo hace un montaje de warmup).
    testWidgets('calentamiento (no se mide)', (tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(_app(BlocProvider.value(
          value: telas10,
          child: const TelasScreen(),
        )));
        await tester.pumpWidget(const SizedBox());
      }
    });

    for (final n in [10, 500]) {
      _widget(
        'TelasScreen montar con $n telas',
        () => _app(BlocProvider.value(
          value: n == 10 ? telas10 : telas500,
          child: const TelasScreen(),
        )),
      );
    }

    for (final n in [10, 500]) {
      _widget(
        'ApliquesScreen montar con $n apliques',
        () => _app(BlocProvider.value(
          value: n == 10 ? apliques10 : apliques500,
          child: const ApliquesScreen(),
        )),
      );
    }

    for (final (n, repeticiones) in [(10, 20), (100, 10), (200, 5)]) {
      _widget(
        'DashboardScreen montar con rankings de $n',
        () => _app(BlocProvider.value(
          value: switch (n) {
            10 => dashboard10,
            100 => dashboard100,
            _ => dashboard200,
          },
          child: const DashboardScreen(),
        )),
        repeticiones: repeticiones,
      );
    }

    // DetVenta reconstruye toda la pantalla (selector de telas + tabla del
    // carrito) en cada emit del cubit: también al tipear precio o cantidad.
    // Pocas repeticiones: es el benchmark que más memoria pide.
    for (final (caso, repeticiones) in [
      ('50 telas, carrito vacío', 10),
      ('200 telas, carrito vacío', 5),
      ('50 telas, carrito de 100 líneas', 5),
    ]) {
      _widget(
        'DetVenta montar ($caso)',
        () => _app(MultiBlocProvider(
          providers: [
            BlocProvider.value(
              value: caso.startsWith('200') ? telasVenta200 : telasVenta50,
            ),
            BlocProvider.value(
              value: caso.endsWith('vacío') ? carritoVacio : carrito100,
            ),
          ],
          child: DetVenta(),
        )),
        repeticiones: repeticiones,
      );
    }
  });
}

/// Presupuestos (ms/montaje): ~10x el peor valor de 3 corridas seguidas de
/// `flutter test benchmark/micro` (JIT, Windows, 2026-10-11), redondeado hacia
/// arriba a 2 cifras. Al agregar un benchmark, agregar su fila (si falta, el
/// archivo no carga); al cambiar de máquina de referencia, recalibrar.
const _presupuestos = <String, double>{
  'TelasScreen montar con 10 telas': 750,
  'TelasScreen montar con 500 telas': 770,
  'ApliquesScreen montar con 10 apliques': 820,
  'ApliquesScreen montar con 500 apliques': 730,
  'DashboardScreen montar con rankings de 10': 500,
  'DashboardScreen montar con rankings de 100': 2100,
  'DashboardScreen montar con rankings de 200': 5700,
  'DetVenta montar (50 telas, carrito vacío)': 2000,
  'DetVenta montar (200 telas, carrito vacío)': 3400,
  'DetVenta montar (50 telas, carrito de 100 líneas)': 4500,
};
