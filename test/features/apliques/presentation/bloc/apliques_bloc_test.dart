import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/apliques_bloc.dart';

import '../../../../helpers/fake_repositories.dart';

/// Devuelve los apliques recién cuando se completa [carga].
class _CargaLenta extends FakeApliquesRepository {
  _CargaLenta({super.apliques});

  final carga = Completer<void>();

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) async {
    await carga.future;
    return super.getApliques(soloActivos: soloActivos);
  }
}

void main() {
  late FakeApliquesRepository repo;

  final apliques = [
    Aplique(id: 1, nombre: 'Flor'),
    Aplique(id: 2, nombre: 'Luna', activo: false),
  ];
  const stock = [
    StockAplique(
        apliqueId: 1, colorId: 1, colorNombre: 'Rojo', hex: '', stock: 5),
  ];

  setUp(() {
    repo = FakeApliquesRepository(apliques: apliques, stock: stock);
  });

  Future<ApliquesBloc> crearBloc({int? idsucursal}) async {
    final bloc = ApliquesBloc(apliquesRepository: repo, idsucursal: idsucursal);
    await pumpEventQueue();
    return bloc;
  }

  group('modo gestión (idsucursal null)', () {
    test('mientras carga marca isLoading y al terminar lo apaga', () async {
      final lenta = _CargaLenta(apliques: apliques);
      final bloc = ApliquesBloc(apliquesRepository: lenta);
      addTearDown(bloc.close);
      try {
        await pumpEventQueue();
        // Sin esto la pantalla no muestra el loader (y un segundo pedido de
        // carga no se descarta)
        expect(bloc.state.isLoading, isTrue);
      } finally {
        lenta.carga.complete();
      }
      await pumpEventQueue();
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.apliques, apliques);
    });

    test('carga todos los apliques (soloActivos false) y sin stock', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);

      expect(repo.lastSoloActivos, false);
      expect(repo.getStockCalls, 0);
      expect(bloc.state.isLoading, false);
      expect(bloc.state.apliques, apliques);
      expect(bloc.state.stock, isEmpty);
    });
  });

  group('modo venta (con idsucursal)', () {
    test('carga solo activos y el stock de la sucursal', () async {
      final bloc = await crearBloc(idsucursal: 4);
      addTearDown(bloc.close);

      expect(repo.lastSoloActivos, true);
      expect(repo.getStockCalls, 1);
      expect(bloc.state.apliques, apliques);
      expect(bloc.state.stock, stock);
    });
  });

  group('operaciones', () {
    test('createAplique agrega al inicio y devuelve true', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);

      final ok = await bloc.createAplique({'nombre': 'Estrella'});
      await pumpEventQueue();

      expect(ok, true);
      expect(bloc.state.apliques.first.id, 99);
      expect(bloc.state.apliques.length, 3);
    });

    test('updateAplique reemplaza el aplique con el mismo id', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);

      final ok = await bloc.updateAplique({'id': 1, 'nombre': 'Flor X'});
      await pumpEventQueue();

      expect(ok, true);
      expect(bloc.state.apliques.map((e) => e.nombre), ['Flor X', 'Luna']);
    });

    test('error del repositorio en create devuelve false', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);
      repo.error = Exception('fallo');

      expect(await bloc.createAplique({'nombre': 'Estrella'}), false);
      expect(bloc.state.apliques.length, 2);
    });

    test('error del repositorio en update devuelve false y no toca la lista',
        () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);
      repo.error = Exception('fallo');

      expect(await bloc.updateAplique({'id': 1, 'nombre': 'Flor X'}), false);
      await pumpEventQueue();
      expect(bloc.state.apliques.map((e) => e.nombre), ['Flor', 'Luna']);
    });
  });
}
