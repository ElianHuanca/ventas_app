import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/aplique_colores_cubit.dart';
import 'package:textiles_app/features/telas/presentation/bloc/tela_colores_cubit.dart';

import '../helpers/fake_repositories.dart';

const colores = [
  ColorItem(id: 1, nombre: 'Rojo', hex: '#FF0000', vinculado: true),
  ColorItem(id: 2, nombre: 'Verde', hex: '#00FF00', vinculado: false),
];

void main() {
  group('TelaColoresCubit', () {
    late FakeTelasRepository repo;

    setUp(() {
      repo = FakeTelasRepository(colores: colores);
    });

    Future<TelaColoresCubit> crearCubit() async {
      final cubit = TelaColoresCubit(telasRepository: repo, idtela: 7);
      await pumpEventQueue();
      return cubit;
    }

    test('load trae los colores de la tela', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isLoading, false);
      expect(cubit.state.colores, colores);
    });

    test('toggleColor actualiza vinculado solo de ese color', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.toggleColor(2, true);

      expect(repo.setColorTelaCalls, [
        [7, 2, true]
      ]);
      expect(cubit.state.colores[0].vinculado, true); // no cambió
      expect(cubit.state.colores[1].vinculado, true); // toggled
    });

    test('toggleColor puede desvincular', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.toggleColor(1, false);

      expect(repo.setColorTelaCalls, [
        [7, 1, false]
      ]);
      expect(cubit.state.colores[0].vinculado, false);
    });

    test('error del repo en toggle no modifica el estado', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      repo.error = Exception('fallo');

      await cubit.toggleColor(2, true);

      expect(cubit.state.colores[1].vinculado, false);
    });
  });

  group('ApliqueColoresCubit', () {
    late FakeApliquesRepository repo;

    setUp(() {
      repo = FakeApliquesRepository(
        colores: colores,
        apliques: [Aplique(id: 3, nombre: 'Flor Petalo Suizo - Bolsa x100 und')],
      );
    });

    Future<ApliqueColoresCubit> crearCubit() async {
      final cubit =
          ApliqueColoresCubit(apliquesRepository: repo, idaplique: 3);
      await pumpEventQueue();
      return cubit;
    }

    test('load trae los colores del aplique', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isLoading, false);
      expect(cubit.state.colores, colores);
    });

    test('load resuelve el nombre del aplique (incluidos inactivos)', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.nombreAplique, 'Flor Petalo Suizo - Bolsa x100 und');
    });

    test('load ordena alfabéticamente sin distinguir mayúsculas', () async {
      repo.colores = const [
        ColorItem(id: 1, nombre: 'Verde', vinculado: false),
        ColorItem(id: 2, nombre: 'azul', vinculado: true),
        ColorItem(id: 3, nombre: 'Blanco', vinculado: true),
        ColorItem(id: 4, nombre: 'Amarillo', vinculado: false),
      ];
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.colores.map((e) => e.nombre),
          ['Amarillo', 'azul', 'Blanco', 'Verde']);
    });

    test('toggleColor actualiza vinculado solo de ese color', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.toggleColor(2, true);

      expect(repo.setColorApliqueCalls, [
        [3, 2, true]
      ]);
      expect(cubit.state.colores[0].vinculado, true); // no cambió
      expect(cubit.state.colores[1].vinculado, true); // toggled
    });

    test('toggleColor puede desvincular', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.toggleColor(1, false);

      expect(repo.setColorApliqueCalls, [
        [3, 1, false]
      ]);
      expect(cubit.state.colores[0].vinculado, false);
    });

    test('error del repo en toggle no modifica el estado', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      repo.error = Exception('fallo');

      await cubit.toggleColor(2, true);

      expect(cubit.state.colores[1].vinculado, false);
    });
  });
}
