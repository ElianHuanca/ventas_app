import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/producciones_historial_cubit.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeApliquesRepository repo;

  const producciones = [
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
    repo = FakeApliquesRepository(producciones: producciones);
  });

  Future<ProduccionesHistorialCubit> crearCubit() async {
    final cubit = ProduccionesHistorialCubit(apliquesRepository: repo);
    await pumpEventQueue();
    return cubit;
  }

  test('carga las producciones al crearse', () async {
    final cubit = await crearCubit();
    addTearDown(cubit.close);

    expect(cubit.state.isLoading, false);
    expect(cubit.state.producciones, producciones);
  });

  test('error del repositorio deja isLoading en false y lista vacía',
      () async {
    repo.error = Exception('fallo');
    final cubit = await crearCubit();
    addTearDown(cubit.close);

    expect(cubit.state.isLoading, false);
    expect(cubit.state.producciones, isEmpty);
  });
}
