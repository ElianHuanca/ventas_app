import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/aplique_form_cubit.dart';

void main() {
  Map<String, dynamic>? mapRecibido;
  bool lanzarError = false;

  Future<bool> fakeCallback(Map<String, dynamic> map) async {
    if (lanzarError) throw Exception('fallo');
    mapRecibido = map;
    return true;
  }

  setUp(() {
    mapRecibido = null;
    lanzarError = false;
  });

  ApliqueFormCubit crearCubit([Aplique? aplique]) => ApliqueFormCubit(
        onCreateCallback: fakeCallback,
        onUpdateCallback: fakeCallback,
        aplique: aplique ?? Aplique.empty(),
      );

  group('estado inicial', () {
    test('aplique nuevo: costo 0 y medidas se muestran vacíos', () {
      final cubit = crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.id, 0);
      expect(cubit.state.nombre, '');
      expect(cubit.state.anchoCm, '');
      expect(cubit.state.altoCm, '');
      expect(cubit.state.costoFabricacion, '');
      expect(cubit.state.activo, true);
    });

    test('aplique existente precarga los campos', () {
      final cubit = crearCubit(Aplique(
          id: 3,
          nombre: 'Flor',
          costoFabricacion: 15,
          anchoCm: 4,
          altoCm: 5.5,
          activo: false));
      addTearDown(cubit.close);

      expect(cubit.state.id, 3);
      expect(cubit.state.nombre, 'Flor');
      expect(cubit.state.anchoCm, '4.0');
      expect(cubit.state.altoCm, '5.5');
      expect(cubit.state.costoFabricacion, '15.0');
      expect(cubit.state.activo, false);
    });
  });

  group('onSubmit validaciones', () {
    test('nombre vacío o solo espacios devuelve false', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      cubit.onCostoChanged('10');

      expect(await cubit.onSubmit(isUpdate: false), false);

      cubit.onNombreChanged('   ');
      expect(await cubit.onSubmit(isUpdate: false), false);
      expect(mapRecibido, isNull);
    });

    test('costo vacío, no numérico o negativo devuelve false', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      cubit.onNombreChanged('Flor');

      expect(await cubit.onSubmit(isUpdate: false), false);

      cubit.onCostoChanged('abc');
      expect(await cubit.onSubmit(isUpdate: false), false);

      cubit.onCostoChanged('-5');
      expect(await cubit.onSubmit(isUpdate: false), false);
      expect(mapRecibido, isNull);
    });

    test('medida no numérica o negativa devuelve false', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      cubit.onNombreChanged('Flor');
      cubit.onCostoChanged('10');

      cubit.onAnchoChanged('abc');
      expect(await cubit.onSubmit(isUpdate: false), false);

      cubit.onAnchoChanged('4');
      cubit.onAltoChanged('-2');
      expect(await cubit.onSubmit(isUpdate: false), false);
      expect(mapRecibido, isNull);
    });
  });

  group('onSubmit map generado', () {
    test('create envía nombre trim, medidas null si vacías, costo numérico y activo',
        () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      cubit.onNombreChanged('  Flor  ');
      cubit.onCostoChanged('12.5');

      final ok = await cubit.onSubmit(isUpdate: false);

      expect(ok, true);
      expect(mapRecibido, {
        'id': 0,
        'nombre': 'Flor',
        'ancho_cm': null,
        'alto_cm': null,
        'costo_fabricacion': 12.5,
        'activo': true,
      });
    });

    test('medidas con valor se envían y update usa el callback de update',
        () async {
      final cubit =
          crearCubit(Aplique(id: 7, nombre: 'Luna', costoFabricacion: 3));
      addTearDown(cubit.close);
      cubit.onAnchoChanged('4');
      cubit.onAltoChanged('5.5');
      cubit.onActivoChanged(false);

      final ok = await cubit.onSubmit(isUpdate: true);

      expect(ok, true);
      expect(mapRecibido!['id'], 7);
      expect(mapRecibido!['ancho_cm'], 4.0);
      expect(mapRecibido!['alto_cm'], 5.5);
      expect(mapRecibido!['activo'], false);
      expect(mapRecibido!.containsKey('tamanio'), false);
    });

    test('callback que lanza devuelve false', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      cubit.onNombreChanged('Flor');
      cubit.onCostoChanged('10');
      lanzarError = true;

      expect(await cubit.onSubmit(isUpdate: false), false);
    });
  });
}
