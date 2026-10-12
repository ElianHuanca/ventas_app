@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Repo cuya carga de sucursales no termina hasta completar [carga].
class _RepoLento extends FakeSucursalesRepository {
  final carga = Completer<List<Sucursal>>();

  @override
  Future<List<Sucursal>> getSucursales() => carga.future;
}

void main() {
  final sucursales = [
    Sucursal(id: 1, nombre: 'Central'),
    Sucursal(id: 2, nombre: 'Norte'),
    Sucursal(id: 3, nombre: 'Sur'),
  ];

  /// La misma pantalla se usa en dos rutas: `/` (inicio, venta de telas:
  /// [gestion] = false) y `/sucursales` (gestión: [gestion] = true).
  Future<void> montar(
    WidgetTester tester,
    FakeSucursalesRepository repo, {
    required bool gestion,
    bool asentar = true,
  }) async {
    // El SucursalesBloc es global en la app (lib/main.dart)
    final bloc = SucursalesBloc(sucursalesRepository: repo);
    addTearDown(bloc.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(value: bloc, child: SucursalesScreen(gestion)),
      asentar: asentar,
    );
  }

  group('inicio (venta de telas)', () {
    testWidgets('una tarjeta por sucursal', (tester) async {
      await montar(
        tester,
        FakeSucursalesRepository(sucursales: sucursales),
        gestion: false,
      );

      await compararCaptura('sucursales_inicio');
    });

    testWidgets('sin sucursales', (tester) async {
      await montar(tester, FakeSucursalesRepository(), gestion: false);

      await compararCaptura('sucursales_inicio_vacia');
    });
  });

  group('gestión de sucursales', () {
    testWidgets('las sucursales y la tarjeta para agregar', (tester) async {
      await montar(
        tester,
        FakeSucursalesRepository(sucursales: sucursales),
        gestion: true,
      );

      await compararCaptura('sucursales_gestion');
    });

    testWidgets('sin sucursales solo queda la tarjeta para agregar',
        (tester) async {
      await montar(tester, FakeSucursalesRepository(), gestion: true);

      await compararCaptura('sucursales_gestion_vacia');
    });
  });

  testWidgets('cargando', (tester) async {
    final lento = _RepoLento();
    await montar(tester, lento, gestion: false, asentar: false);
    // En el instante 0 el arco del indicador todavía no se ve: se avanza un
    // tiempo fijo de su animación (el reloj del test es determinístico).
    await tester.pump(const Duration(milliseconds: 400));

    // Se libera la carga aunque la captura falle: si no, el close() del
    // bloc espera ese handler y el test se cuelga hasta el timeout.
    try {
      await compararCaptura('sucursales_cargando');
    } finally {
      lento.carga.complete(sucursales);
    }
  });
}
