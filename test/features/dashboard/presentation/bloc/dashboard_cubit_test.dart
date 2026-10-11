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

  // bug: dashboard_cubit.dart:70-88 — cargar() tiene try/finally sin catch
  // (todos los demás cubits atrapan): si una RPC falla (sin conexión) la
  // excepción escapa sin atrapar —el constructor llama a cargar() sin await—
  // y la pantalla muestra "Sin ventas de … en el período seleccionado" como
  // si no hubiera ventas.
  test('si una RPC falla, cargar no lanza y deja de cargar', () async {
    final repo = _DashboardSinConexion(topTelas: const [
      TopProducto(nombre: 'Lino', totalVendido: 10, totalCantidad: 1),
    ]);
    final cubit = DashboardCubit(repository: repo);
    addTearDown(cubit.close);

    await expectLater(cubit.cargar(), completes);
    expect(cubit.state.isLoading, isFalse);

    // Al volver la conexión, cambiar de período recupera los datos
    repo.fallar = false;
    await cubit.cambiarRango(DateTime(2026, 1, 1), DateTime(2026, 1, 31));
    expect(cubit.state.topTelas.single.nombre, 'Lino');
  }, skip: true);
}
