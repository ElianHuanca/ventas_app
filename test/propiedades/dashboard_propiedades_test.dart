import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';

import '../helpers/fake_repositories.dart';
import 'generadores.dart';

/// Los rankings del dashboard: "por cantidad" reordena una copia y "por
/// monto" deja el orden de las RPC.
void main() {
  propiedad(
      'por cantidad es una permutación ordenada de mayor a menor y no '
      'toca la lista del estado',
      _ranking, (ranking) {
    final antes = List.of(ranking);
    final state = DashboardState(
      top: ranking,
      verPorCantidad: true,
      desde: DateTime(2026, 10, 1),
      hasta: DateTime(2026, 10, 11),
    );

    final ordenada = state.ordenados;
    expect(ordenada, unorderedEquals(state.top),
        reason: 'mismos productos (por identidad), ni más ni menos');
    for (var i = 1; i < ordenada.length; i++) {
      expect(ordenada[i - 1].totalCantidad,
          greaterThanOrEqualTo(ordenada[i].totalCantidad),
          reason: 'descendente por cantidad en la posición $i');
    }
    expect(state.top, orderedEquals(antes),
        reason: 'la lista del estado sigue en el orden de la RPC');
  }, casos: 1000);

  propiedad('por monto deja el orden de la RPC', _ranking, (ranking) {
    final state = DashboardState(
      top: ranking,
      desde: DateTime(2026, 10, 1),
      hasta: DateTime(2026, 10, 11),
    );

    expect(state.ordenados, orderedEquals(ranking));
  }, casos: 1000);

  propiedad(
      'con el cubit: alternar la vista dos veces vuelve al orden por '
      'monto y la lista cargada nunca cambia',
      _ranking, (apliques) async {
    final cubit = DashboardCubit(
      repository: FakeDashboardRepository(topApliques: apliques),
      linea: LineaDashboard.apliques,
    );
    try {
      await cubit.cargar();
      final cargada = List.of(cubit.state.top);

      cubit.toggleVista();
      final porCantidad = cubit.state.ordenados;
      cubit.toggleVista();

      expect(porCantidad, unorderedEquals(cargada));
      expect(cubit.state.ordenados, orderedEquals(cargada));
      expect(cubit.state.top, orderedEquals(cargada));
    } finally {
      await cubit.close();
    }
  });
}

/// Un ranking como lo devuelve la RPC: ordenado por monto, con muchos
/// empates de cantidad (entre empatados el orden no está definido y la
/// propiedad no lo asume).
final _ranking = any
    .listWithLengthInRange(
      0,
      15,
      any.combine2(
        any.entero(0, 1000),
        // pocas cantidades distintas: muchos empates
        any.entero(0, 8),
        (int id, int cantidad) => TopProducto(
          nombre: 'Producto $id',
          totalVendido: id * 10.0,
          totalCantidad: cantidad * 2.5,
        ),
      ),
    )
    .map((lista) =>
        lista..sort((a, b) => b.totalVendido.compareTo(a.totalVendido)));
