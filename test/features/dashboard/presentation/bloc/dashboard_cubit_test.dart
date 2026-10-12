import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';

import '../../../../helpers/fake_repositories.dart';

/// Las RPC del resumen fallan (sin conexión) mientras [fallar] sea true.
class _DashboardSinConexion extends FakeDashboardRepository {
  bool fallar = true;

  _DashboardSinConexion({super.topTelas});

  @override
  Future<ResumenVentas> getResumenVentas(
      {required DateTime desde, required DateTime hasta}) async {
    if (fallar) throw Exception('Sin conexión');
    return super.getResumenVentas(desde: desde, hasta: hasta);
  }
}

void main() {
  // Al fallar una carga el cubit arma un DashboardState nuevo para tirar los
  // datos del período anterior: depende de que uno nuevo venga vacío.
  test('un DashboardState nuevo no trae datos, no carga y no marca error', () {
    final estado = DashboardState(
        desde: DateTime(2026, 1, 1), hasta: DateTime(2026, 1, 31));

    expect(estado.isLoading, isFalse);
    expect(estado.error, isFalse);
    expect(estado.verPorCantidad, isFalse);
    expect(estado.topTelas, isEmpty);
    expect(estado.topApliques, isEmpty);
    expect(estado.resumenTelas, isNull);
    expect(estado.resumenApliques, isNull);
  });

  test('el estado inicial es el mes actual hasta hoy, por monto', () async {
    final antes = DateTime.now();
    final cubit = DashboardCubit(repository: FakeDashboardRepository());
    addTearDown(cubit.close);

    expect(cubit.state.desde, DateTime(antes.year, antes.month, 1));
    expect(cubit.state.hasta.isBefore(antes), isFalse);
    expect(cubit.state.verPorCantidad, isFalse);
  });

  test('por cantidad no reordena la lista original del estado', () async {
    const top = [
      TopProducto(nombre: 'Lino', totalVendido: 500, totalCantidad: 1),
      TopProducto(nombre: 'Seda', totalVendido: 100, totalCantidad: 9),
    ];
    final cubit =
        DashboardCubit(repository: FakeDashboardRepository(topTelas: top));
    addTearDown(cubit.close);
    await cubit.cargar();

    cubit.toggleVista();

    expect(cubit.state.telasOrdenadas.map((p) => p.nombre), ['Seda', 'Lino']);
    expect(cubit.state.topTelas.map((p) => p.nombre), ['Lino', 'Seda']);
  });

  test('cambiar de rango conserva la vista elegida', () async {
    final cubit = DashboardCubit(repository: FakeDashboardRepository());
    addTearDown(cubit.close);
    await cubit.cargar();
    cubit.toggleVista();

    await cubit.cambiarRango(DateTime(2026, 1, 1), DateTime(2026, 1, 31));

    expect(cubit.state.verPorCantidad, isTrue);
    expect(cubit.state.isLoading, isFalse);
  });

  // Sin conexión la pantalla no puede mostrar el período como "Sin ventas":
  // el estado marca el error (ver dashboard_screen_test).
  test('si una RPC falla, cargar no lanza, deja de cargar y marca el error',
      () async {
    final repo = _DashboardSinConexion(topTelas: const [
      TopProducto(nombre: 'Lino', totalVendido: 10, totalCantidad: 1),
    ]);
    final cubit = DashboardCubit(repository: repo);
    addTearDown(cubit.close);

    await expectLater(cubit.cargar(), completes);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.error, isTrue);
    expect(cubit.state.topTelas, isEmpty);
    expect(cubit.state.resumenTelas, isNull);

    // Al volver la conexión, cambiar de período recupera los datos
    repo.fallar = false;
    await cubit.cambiarRango(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
    expect(cubit.state.error, isFalse);
    expect(cubit.state.topTelas.single.nombre, 'Lino');
  });
}
