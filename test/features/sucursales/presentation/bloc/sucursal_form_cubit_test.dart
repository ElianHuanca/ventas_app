import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/sucursal_form_cubit.dart';

void main() {
  Map<String, dynamic>? mapRecibido;
  int? idBorrado;
  bool lanzarError = false;

  Future<bool> fakeSubmit(Map<String, dynamic> map) async {
    if (lanzarError) throw Exception('fallo');
    mapRecibido = map;
    return true;
  }

  Future<bool> fakeDelete(int id) async {
    if (lanzarError) throw Exception('fallo');
    idBorrado = id;
    return true;
  }

  setUp(() {
    mapRecibido = null;
    idBorrado = null;
    lanzarError = false;
  });

  SucursalFormCubit crearCubit([Sucursal? sucursal]) => SucursalFormCubit(
        onCreateCallback: fakeSubmit,
        onUpdateCallback: fakeSubmit,
        onDeleteCallback: fakeDelete,
        sucursal: sucursal ?? Sucursal.empty(),
      );

  test('estado inicial precarga la sucursal', () {
    final cubit = crearCubit(Sucursal(id: 4, nombre: 'Norte'));
    addTearDown(cubit.close);

    expect(cubit.state.id, 4);
    expect(cubit.state.nombre, 'Norte');
  });

  test('submit con nombre vacío devuelve false sin llamar callbacks', () async {
    final cubit = crearCubit();
    addTearDown(cubit.close);

    expect(await cubit.onSubmit(isUpdate: false), false);
    expect(mapRecibido, isNull);
  });

  test('nombre de solo espacios devuelve false sin llamar callbacks', () async {
    final cubit = crearCubit();
    addTearDown(cubit.close);
    cubit.onNombreChanged('   ');

    expect(await cubit.onSubmit(isUpdate: false), false);
    expect(mapRecibido, isNull);
  });

  test('el nombre se guarda con trim', () async {
    final cubit = crearCubit();
    addTearDown(cubit.close);
    cubit.onNombreChanged('  Centro  ');

    final ok = await cubit.onSubmit(isUpdate: false);

    expect(ok, true);
    expect(mapRecibido, {'id': 0, 'nombre': 'Centro'});
  });

  test('create envía el map con id y nombre', () async {
    final cubit = crearCubit();
    addTearDown(cubit.close);
    cubit.onNombreChanged('Centro');

    final ok = await cubit.onSubmit(isUpdate: false);

    expect(ok, true);
    expect(mapRecibido, {'id': 0, 'nombre': 'Centro'});
  });

  test('update envía el id existente', () async {
    final cubit = crearCubit(Sucursal(id: 4, nombre: 'Norte'));
    addTearDown(cubit.close);
    cubit.onNombreChanged('Norte II');

    final ok = await cubit.onSubmit(isUpdate: true);

    expect(ok, true);
    expect(mapRecibido, {'id': 4, 'nombre': 'Norte II'});
  });

  test('callback que lanza devuelve false', () async {
    final cubit = crearCubit();
    addTearDown(cubit.close);
    cubit.onNombreChanged('Centro');
    lanzarError = true;

    expect(await cubit.onSubmit(isUpdate: false), false);
  });

  group('onDelete', () {
    test('llama al callback con el id del estado', () async {
      final cubit = crearCubit(Sucursal(id: 9, nombre: 'Sur'));
      addTearDown(cubit.close);

      final ok = await cubit.onDelete();

      expect(ok, true);
      expect(idBorrado, 9);
    });

    test('callback que lanza devuelve false', () async {
      final cubit = crearCubit(Sucursal(id: 9, nombre: 'Sur'));
      addTearDown(cubit.close);
      lanzarError = true;

      expect(await cubit.onDelete(), false);
    });
  });
}
