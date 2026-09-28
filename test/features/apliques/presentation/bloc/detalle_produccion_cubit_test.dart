import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/detalle_produccion_cubit.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeApliquesRepository repo;

  const lineas = [
    Produccion(
      id: 1,
      fecha: '2024-01-01',
      sucursalNombre: 'Centro',
      apliqueNombre: 'Flor',
      colorNombre: 'Rojo',
      cantidad: 5,
    ),
  ];

  setUp(() {
    repo = FakeApliquesRepository(detalleProduccion: lineas);
  });

  Future<DetalleProduccionCubit> crearCubit() async {
    final cubit =
        DetalleProduccionCubit(apliquesRepository: repo, idproduccion: 7);
    await pumpEventQueue();
    return cubit;
  }

  test('carga el detalle de la producción al crearse', () async {
    final cubit = await crearCubit();
    addTearDown(cubit.close);

    expect(cubit.state.isLoading, false);
    expect(cubit.state.lineas, lineas);
    expect(repo.lastGetDetalleProduccionId, 7);
  });

  test('error del repositorio deja isLoading en false y lista vacía',
      () async {
    repo.error = Exception('fallo');
    final cubit = await crearCubit();
    addTearDown(cubit.close);

    expect(cubit.state.isLoading, false);
    expect(cubit.state.lineas, isEmpty);
  });
}
