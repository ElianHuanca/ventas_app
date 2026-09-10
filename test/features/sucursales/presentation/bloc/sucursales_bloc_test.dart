import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/sucursales_bloc.dart';

import '../../../../helpers/fake_repositories.dart';

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
}
