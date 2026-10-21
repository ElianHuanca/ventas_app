import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/sucursales_bloc.dart';

import '../../../../helpers/fake_repositories.dart';

/// Devuelve las sucursales recién cuando se completa [carga].
class _CargaLenta extends FakeSucursalesRepository {
  _CargaLenta({super.sucursales});

  final carga = Completer<void>();

  @override
  Future<List<Sucursal>> getSucursales() async {
    await carga.future;
    return super.getSucursales();
  }
}

void main() {
  late FakeSucursalesRepository repo;

  final sucursales = [
    Sucursal(id: 1, nombre: 'Centro'),
    Sucursal(id: 2, nombre: 'Norte'),
  ];

  setUp(() {
    repo = FakeSucursalesRepository(sucursales: sucursales);
  });

  Future<SucursalesBloc> crearBloc() async {
    final bloc = SucursalesBloc(sucursalesRepository: repo);
    await pumpEventQueue();
    return bloc;
  }

  test('mientras carga marca isLoading y al terminar lo apaga', () async {
    final lenta = _CargaLenta(sucursales: sucursales);
    final bloc = SucursalesBloc(sucursalesRepository: lenta);
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
    expect(bloc.state.sucursales, sucursales);
  });

  test('carga inicial trae las sucursales', () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);

    expect(bloc.state.isLoading, false);
    expect(bloc.state.sucursales, sucursales);
  });

  test('error del repositorio deja la lista vacía', () async {
    repo.error = Exception('fallo');
    final bloc = await crearBloc();
    addTearDown(bloc.close);

    expect(bloc.state.isLoading, false);
    expect(bloc.state.sucursales, isEmpty);
  });

  test('createSucursal agrega al final y devuelve true', () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);

    final ok = await bloc.createSucursal({'nombre': 'Sur'});
    await pumpEventQueue();

    expect(ok, true);
    expect(bloc.state.sucursales.last.nombre, 'Sur');
    expect(bloc.state.sucursales.length, 3);
  });

  test('updateSucursal reemplaza la sucursal con el mismo id', () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);

    final ok = await bloc.updateSucursal({'id': 2, 'nombre': 'Norte II'});
    await pumpEventQueue();

    expect(ok, true);
    expect(bloc.state.sucursales.map((e) => e.nombre), ['Centro', 'Norte II']);
  });

  test('deleteSucursal quita la sucursal cuando el repo confirma', () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);

    final ok = await bloc.deleteSucursal(1);
    await pumpEventQueue();

    expect(ok, true);
    expect(bloc.state.sucursales.map((e) => e.id), [2]);
  });

  test('deleteSucursal con respuesta false no modifica la lista', () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);
    repo.deleteResult = false;

    final ok = await bloc.deleteSucursal(1);

    expect(ok, false);
    expect(bloc.state.sucursales.length, 2);
  });

  test('error del repositorio en create devuelve false', () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);
    repo.error = Exception('fallo');

    expect(await bloc.createSucursal({'nombre': 'Sur'}), false);
    expect(bloc.state.sucursales.length, 2);
  });

  test('error del repositorio en update devuelve false y no toca la lista',
      () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);
    repo.error = Exception('fallo');

    expect(await bloc.updateSucursal({'id': 2, 'nombre': 'Norte II'}), false);
    await pumpEventQueue();
    expect(bloc.state.sucursales.map((e) => e.nombre), ['Centro', 'Norte']);
  });

  test('error del repositorio en delete devuelve false y no toca la lista',
      () async {
    final bloc = await crearBloc();
    addTearDown(bloc.close);
    repo.error = Exception('fallo');

    expect(await bloc.deleteSucursal(1), false);
    await pumpEventQueue();
    expect(bloc.state.sucursales.map((e) => e.id), [1, 2]);
  });
}
