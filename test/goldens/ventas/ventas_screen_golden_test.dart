@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Deja la carga de ventas en espera hasta completar [carga].
class _RepoConCargaPendiente extends FakeVentasRepository {
  final carga = Completer<List<Venta>>();

  @override
  Future<List<Venta>> getVentas(int idsucursal) => carga.future;
}

Venta _venta(int id, DateTime fecha, double total, double ganancias,
        double descuento) =>
    Venta(
      id: id,
      fecha: fecha,
      total: total,
      ganancias: ganancias,
      descuento: descuento,
      idsucursales: 1,
    );

void main() {
  // La pantalla solo muestra la fecha de cada venta (una por día); los
  // totales se ven en el detalle.
  final ventas = [
    _venta(6, DateTime(2026, 10, 10), 1250, 430, 20),
    _venta(5, DateTime(2026, 10, 9), 870.5, 290, 0),
    _venta(4, DateTime(2026, 10, 8), 2310, 815, 50),
    _venta(3, DateTime(2026, 10, 6), 640, 210, 0),
    _venta(2, DateTime(2026, 10, 3), 1580, 520, 10),
  ];

  Future<void> montar(
    WidgetTester tester,
    FakeVentasRepository repo, {
    bool asentar = true,
  }) async {
    final bloc = VentasBloc(ventasRepository: repo, idsucursal: 1);
    addTearDown(bloc.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: bloc,
        child: const VentasScreen(idsucursal: 1),
      ),
      asentar: asentar,
    );
  }

  testWidgets('ventas de la sucursal, una por día', (tester) async {
    await montar(tester, FakeVentasRepository(ventas: ventas));

    await compararCaptura('ventas_lista');
  });

  testWidgets('sin ventas', (tester) async {
    await montar(tester, FakeVentasRepository());

    await compararCaptura('ventas_vacia');
  });

  testWidgets('cargando', (tester) async {
    // El loader no pinta fondo (bug en full_screen_loader_golden_test.dart)
    final repo = _RepoConCargaPendiente();
    await montar(tester, repo, asentar: false);
    // En el primer frame el spinner es un punto: se avanza a un instante fijo
    await tester.pump(const Duration(milliseconds: 400));

    // Se libera la carga aunque la captura falle: si no, el close() del
    // bloc espera ese handler y el test se cuelga hasta el timeout.
    try {
      await compararCaptura('ventas_cargando');
    } finally {
      repo.carga.complete(ventas);
    }
    await tester.pumpAndSettle();
  });
}
