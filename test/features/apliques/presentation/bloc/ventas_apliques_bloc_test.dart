import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/ventas_apliques_bloc.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeVentasApliquesRepository repo;

  final ventas = [
    VentaAplique(id: 1, fecha: DateTime(2024, 5, 10)),
    VentaAplique(id: 2, fecha: DateTime(2024, 5, 10, 15, 30)),
    VentaAplique(id: 3, fecha: DateTime(2024, 5, 9)),
  ];

  setUp(() {
    repo = FakeVentasApliquesRepository(ventas: ventas);
  });

  Future<VentasApliquesBloc> crearBloc() async {
    final bloc =
        VentasApliquesBloc(ventasApliquesRepository: repo, idsucursal: 1);
    await pumpEventQueue();
    return bloc;
  }

  test('carga las ventas de la sucursal al crearse', () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);

    expect(bloc.state.isLoading, false);
    expect(bloc.state.ventas, ventas);
    expect(repo.lastGetVentasApliquesSucursalId, 1);
  });

  test('VentasApliquesLoadRequested recarga la lista', () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);
    final nuevas = [VentaAplique(id: 4, fecha: DateTime(2024, 5, 11))];
    repo.ventas = nuevas;

    bloc.add(VentasApliquesLoadRequested(1));
    await pumpEventQueue();

    expect(bloc.state.isLoading, false);
    expect(bloc.state.ventas, nuevas);
  });

  test('error del repositorio deja isLoading en false y lista vacía',
      () async {
    repo.error = Exception('fallo');
    final bloc = await crearBloc();
    addTearDown(bloc.close);

    expect(bloc.state.isLoading, false);
    expect(bloc.state.ventas, isEmpty);
  });
}
