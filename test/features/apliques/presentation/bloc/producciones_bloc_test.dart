import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/producciones_bloc.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeApliquesRepository repo;

  final cabeceras = [
    ProduccionCabecera(id: 1, fecha: DateTime(2024, 5, 10)),
    ProduccionCabecera(id: 2, fecha: DateTime(2024, 5, 9)),
  ];

  setUp(() {
    repo = FakeApliquesRepository(producciones: cabeceras);
  });

  Future<ProduccionesBloc> crearBloc() async {
    final bloc = ProduccionesBloc(apliquesRepository: repo, idsucursal: 1);
    await pumpEventQueue();
    return bloc;
  }

  test('carga las producciones de la sucursal al crearse', () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);

    expect(bloc.state.isLoading, false);
    expect(bloc.state.producciones, cabeceras);
    expect(repo.lastGetProduccionesSucursalId, 1);
  });

  test('ProduccionesLoadRequested recarga la lista', () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);
    final nuevas = [ProduccionCabecera(id: 3, fecha: DateTime(2024, 5, 11))];
    repo.producciones = nuevas;

    bloc.add(ProduccionesLoadRequested(1));
    await pumpEventQueue();

    expect(bloc.state.isLoading, false);
    expect(bloc.state.producciones, nuevas);
  });

  test('isLoading queda en true mientras espera al repositorio', () async {
    final pendiente = _RepoConCargaPendiente();
    final bloc = ProduccionesBloc(apliquesRepository: pendiente, idsucursal: 1);
    addTearDown(bloc.close);
    await pumpEventQueue();

    expect(bloc.state.isLoading, true);

    pendiente.carga.complete(cabeceras);
    await pumpEventQueue();

    expect(bloc.state.isLoading, false);
    expect(bloc.state.producciones, cabeceras);
  });

  test('error del repositorio deja isLoading en false y lista vacía', () async {
    repo.error = Exception('fallo');
    final bloc = await crearBloc();
    addTearDown(bloc.close);

    expect(bloc.state.isLoading, false);
    expect(bloc.state.producciones, isEmpty);
  });
}

/// Deja la carga en espera hasta completar [carga].
class _RepoConCargaPendiente extends FakeApliquesRepository {
  final carga = Completer<List<ProduccionCabecera>>();

  @override
  Future<List<ProduccionCabecera>> getProducciones(int sucursalId) =>
      carga.future;
}
