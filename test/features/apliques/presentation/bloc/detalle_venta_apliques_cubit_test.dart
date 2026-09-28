import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/detalle_venta_apliques_cubit.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeVentasApliquesRepository repo;

  const lineas = [
    DetalleVentaAplique(
      id: 1,
      nombre: 'Flor (Rojo)',
      cantidad: 3,
      precio: 10,
      total: 30,
    ),
    DetalleVentaAplique(
      id: 2,
      nombre: 'Luna (Azul)',
      cantidad: 2,
      precio: 15,
      total: 30,
    ),
  ];

  setUp(() {
    repo = FakeVentasApliquesRepository(detalle: lineas);
  });

  Future<DetalleVentaApliquesCubit> crearCubit() async {
    final cubit =
        DetalleVentaApliquesCubit(ventasApliquesRepository: repo, idventa: 7);
    await pumpEventQueue();
    return cubit;
  }

  test('carga las líneas de la venta al crearse', () async {
    final cubit = await crearCubit();
    addTearDown(cubit.close);

    expect(cubit.state.isLoading, false);
    expect(cubit.state.lineas, lineas);
    expect(repo.lastGetDetalleIdventa, 7);
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
