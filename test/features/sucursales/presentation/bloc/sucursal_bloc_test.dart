import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/sucursal_bloc.dart';

import '../../../../helpers/fake_repositories.dart';

/// El fake compartido no cuenta las llamadas a getSucursal ni lanza en ella:
/// esta subclase agrega ambas cosas.
class _RepoSucursal extends FakeSucursalesRepository {
  _RepoSucursal({super.sucursales});

  final List<int> idsPedidos = [];
  Exception? errorGetSucursal;

  @override
  Future<Sucursal> getSucursal(int id) async {
    idsPedidos.add(id);
    if (errorGetSucursal != null) throw errorGetSucursal!;
    return super.getSucursal(id);
  }
}

void main() {
  late _RepoSucursal repo;

  final sucursales = [
    Sucursal(id: 1, nombre: 'Centro'),
    Sucursal(id: 2, nombre: 'Norte'),
  ];

  setUp(() {
    repo = _RepoSucursal(sucursales: sucursales);
  });

  Future<SucursalBloc> crearBloc(int id) async {
    final bloc = SucursalBloc(sucursalesRepository: repo, id: id);
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  test('arranca cargando con el id recibido y sin sucursal', () {
    final bloc = SucursalBloc(sucursalesRepository: repo, id: 2);
    addTearDown(bloc.close);

    expect(bloc.state.id, 2);
    expect(bloc.state.isLoading, true);
    expect(bloc.state.sucursal, isNull);
  });

  test('carga la sucursal por id', () async {
    final bloc = await crearBloc(2);

    expect(bloc.state.isLoading, false);
    expect(bloc.state.id, 2);
    expect(bloc.state.sucursal!.id, 2);
    expect(bloc.state.sucursal!.nombre, 'Norte');
    expect(repo.idsPedidos, [2]);
  });

  test('id 0 devuelve una sucursal vacía sin consultar al repositorio',
      () async {
    final bloc = await crearBloc(0);

    expect(bloc.state.isLoading, false);
    expect(bloc.state.sucursal!.id, 0);
    expect(bloc.state.sucursal!.nombre, '');
    expect(repo.idsPedidos, isEmpty);
  });

  test('id inexistente queda con la sucursal vacía que devuelve el repo',
      () async {
    // El datasource real devuelve Sucursal.empty() si no encuentra la fila.
    final bloc = await crearBloc(99);

    expect(bloc.state.isLoading, false);
    expect(bloc.state.id, 99);
    expect(bloc.state.sucursal!.id, 0);
    expect(bloc.state.sucursal!.nombre, '');
    expect(repo.idsPedidos, [99]);
  });

  test('error del repositorio termina la carga sin sucursal', () async {
    repo.errorGetSucursal = Exception('sin conexión');
    final bloc = await crearBloc(1);

    expect(bloc.state.isLoading, false);
    expect(bloc.state.sucursal, isNull);
    expect(repo.idsPedidos, [1]);
  });
}
