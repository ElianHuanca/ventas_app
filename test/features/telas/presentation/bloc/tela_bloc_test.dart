import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/tela_bloc.dart';

import '../../../../helpers/fake_repositories.dart';

/// Registra los ids pedidos a getTela y permite simular un fallo (el fake
/// compartido no lanza en getTela).
class _Repo extends FakeTelasRepository {
  _Repo({super.telas});

  final List<int> getTelaIds = [];
  Exception? getTelaError;

  @override
  Future<Tela> getTela(int id) async {
    getTelaIds.add(id);
    if (getTelaError != null) throw getTelaError!;
    return super.getTela(id);
  }
}

void main() {
  late _Repo repo;

  final telas = [
    Tela(
      id: 3,
      nombre: 'Lino',
      precxmen: 10,
      precxmay: 8,
      precxrollo: 300,
      precxcompra: 6,
      activo: false,
    ),
    Tela(id: 4, nombre: 'Seda'),
  ];

  setUp(() {
    repo = _Repo(telas: telas);
  });

  Future<TelaBloc> crearBloc(int id) async {
    final bloc = TelaBloc(telasRepository: repo, id: id);
    await pumpEventQueue();
    return bloc;
  }

  test('arranca cargando con el id pedido y sin tela', () {
    final bloc = TelaBloc(telasRepository: repo, id: 3);
    addTearDown(bloc.close);

    expect(bloc.state.isLoading, true);
    expect(bloc.state.id, 3);
    expect(bloc.state.tela, isNull);
  });

  test('con id existente carga esa tela del repositorio', () async {
    final bloc = await crearBloc(3);
    addTearDown(bloc.close);

    expect(repo.getTelaIds, [3]);
    expect(bloc.state.isLoading, false);
    expect(bloc.state.id, 3);
    final tela = bloc.state.tela!;
    expect(tela.id, 3);
    expect(tela.nombre, 'Lino');
    expect(tela.precxmen, 10);
    expect(tela.precxrollo, 300);
    expect(tela.activo, false);
  });

  test('con id 0 (alta) devuelve una tela vacía sin consultar al repositorio',
      () async {
    final bloc = await crearBloc(0);
    addTearDown(bloc.close);

    expect(repo.getTelaIds, isEmpty);
    expect(bloc.state.isLoading, false);
    final tela = bloc.state.tela!;
    expect(tela.id, 0);
    expect(tela.nombre, '');
    expect(tela.activo, true);
  });

  test('con id inexistente queda la tela vacía que devuelve el repositorio',
      () async {
    final bloc = await crearBloc(77);
    addTearDown(bloc.close);

    expect(repo.getTelaIds, [77]);
    expect(bloc.state.isLoading, false);
    // El id pedido se conserva, pero la tela es la vacía (id 0)
    expect(bloc.state.id, 77);
    expect(bloc.state.tela!.id, 0);
    expect(bloc.state.tela!.nombre, '');
  });

  test('error del repositorio deja de cargar y no deja tela', () async {
    repo.getTelaError = Exception('sin conexión');
    final bloc = await crearBloc(3);
    addTearDown(bloc.close);

    expect(repo.getTelaIds, [3]);
    expect(bloc.state.isLoading, false);
    expect(bloc.state.tela, isNull);
  });
}
