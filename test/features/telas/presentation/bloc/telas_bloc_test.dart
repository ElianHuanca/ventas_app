import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/telas_bloc.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeTelasRepository repo;

  final telas = [
    Tela(id: 1, nombre: 'Lino'),
    Tela(id: 2, nombre: 'Seda'),
  ];

  setUp(() {
    repo = FakeTelasRepository(telas: telas);
  });

  Future<TelasBloc> crearBloc({int? idsucursal}) async {
    final bloc = TelasBloc(telasRepository: repo, idsucursal: idsucursal);
    await pumpEventQueue();
    return bloc;
  }

  group('carga inicial', () {
    test('sin idsucursal usa getTelas incluyendo inactivas', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);

      expect(repo.getTelasUsado, true);
      expect(repo.lastSoloActivos, false);
      expect(repo.getTelasPorSucursalUsado, false);
      expect(bloc.state.isLoading, false);
      expect(bloc.state.telas, telas);
    });

    test('con idsucursal usa getTelasPorSucursal', () async {
      final bloc = await crearBloc(idsucursal: 3);
      addTearDown(bloc.close);

      expect(repo.getTelasPorSucursalUsado, true);
      expect(repo.lastIdsucursal, 3);
      expect(repo.getTelasUsado, false);
      expect(bloc.state.telas, telas);
    });

    test('error del repositorio deja la lista vacía y deja de cargar',
        () async {
      repo.error = Exception('fallo');
      final bloc = await crearBloc();
      addTearDown(bloc.close);

      expect(bloc.state.isLoading, false);
      expect(bloc.state.telas, isEmpty);
    });
  });

  group('operaciones', () {
    test('createTela agrega la tela al inicio y devuelve true', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);

      final ok = await bloc.createTela({'nombre': 'Gasa'});
      await pumpEventQueue();

      expect(ok, true);
      expect(bloc.state.telas.first.id, 99);
      expect(bloc.state.telas.first.nombre, 'Gasa');
      expect(bloc.state.telas.length, 3);
    });

    test('createTela con error devuelve false y no modifica la lista',
        () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);
      repo.error = Exception('fallo');

      final ok = await bloc.createTela({'nombre': 'Gasa'});

      expect(ok, false);
      expect(bloc.state.telas.length, 2);
    });

    test('updateTela reemplaza la tela con el mismo id', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);

      final ok = await bloc.updateTela({'id': 1, 'nombre': 'Lino Premium'});
      await pumpEventQueue();

      expect(ok, true);
      expect(bloc.state.telas.map((e) => e.nombre),
          ['Lino Premium', 'Seda']);
    });
  });
}
