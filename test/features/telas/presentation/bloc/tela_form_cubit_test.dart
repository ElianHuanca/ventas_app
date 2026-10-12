import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/tela_form_cubit.dart';

void main() {
  Map<String, dynamic>? mapRecibido;
  bool lanzarError = false;

  Future<bool> fakeSubmit(Map<String, dynamic> map) async {
    if (lanzarError) throw Exception('fallo');
    mapRecibido = map;
    return true;
  }

  setUp(() {
    mapRecibido = null;
    lanzarError = false;
  });

  TelaFormCubit crearCubit([Tela? tela]) => TelaFormCubit(
        onCreateCallback: fakeSubmit,
        onUpdateCallback: fakeSubmit,
        tela: tela ?? Tela.empty(),
      );

  void completarFormulario(TelaFormCubit cubit) {
    cubit.onNombreChanged('Lino');
    cubit.onPrecxmenChanged('100');
    cubit.onPrecxmayChanged('80');
    cubit.onPrecxrolloChanged('70');
    cubit.onPrecxcompraChanged('50');
  }

  group('estado inicial', () {
    test('tela nueva deja precios vacíos y activo en true', () {
      final cubit = crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.precxmen, '');
      expect(cubit.state.precxmay, '');
      expect(cubit.state.precxrollo, '');
      expect(cubit.state.precxcompra, '');
      expect(cubit.state.activo, true);
    });

    test('tela existente precarga sus precios (también los 0) y su activo', () {
      final cubit = crearCubit(Tela(
        id: 2,
        nombre: 'Seda',
        precxmen: 120,
        precxmay: 0,
        precxrollo: 90,
        precxcompra: 60,
        activo: false,
      ));
      addTearDown(cubit.close);

      expect(cubit.state.precxmen, '120.0');
      // 0 = no se vende así: se muestra, si no habría que reescribirlo
      expect(cubit.state.precxmay, '0.0');
      expect(cubit.state.precxrollo, '90.0');
      expect(cubit.state.precxcompra, '60.0');
      expect(cubit.state.activo, false);
    });
  });

  group('onSubmit validaciones', () {
    test('nombre vacío devuelve false', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      cubit.onPrecxmenChanged('100');
      cubit.onPrecxmayChanged('80');
      cubit.onPrecxrolloChanged('70');
      cubit.onPrecxcompraChanged('50');

      expect(await cubit.onSubmit(isUpdate: false), false);
      expect(mapRecibido, isNull);
    });

    test('cualquier precio vacío devuelve false', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      cubit.onNombreChanged('Lino');
      cubit.onPrecxmenChanged('100');
      cubit.onPrecxmayChanged('80');
      cubit.onPrecxrolloChanged('70');
      // falta precxcompra

      expect(await cubit.onSubmit(isUpdate: false), false);
    });

    test('precio no numérico devuelve false', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      completarFormulario(cubit);
      cubit.onPrecxmayChanged('abc');

      expect(await cubit.onSubmit(isUpdate: false), false);
    });

    test('precio negativo devuelve false', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      completarFormulario(cubit);
      cubit.onPrecxcompraChanged('-10');

      expect(await cubit.onSubmit(isUpdate: false), false);
      expect(mapRecibido, isNull);
    });

    test('nombre de solo espacios devuelve false', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      completarFormulario(cubit);
      cubit.onNombreChanged('   ');

      expect(await cubit.onSubmit(isUpdate: false), false);
      expect(mapRecibido, isNull);
    });
  });

  group('onSubmit map generado', () {
    test('create envía precios parseados a double', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      completarFormulario(cubit);

      final ok = await cubit.onSubmit(isUpdate: false);

      expect(ok, true);
      expect(mapRecibido, {
        'id': 0,
        'nombre': 'Lino',
        'precxmen': 100.0,
        'precxmay': 80.0,
        'precxrollo': 70.0,
        'precxcompra': 50.0,
        'activo': true,
      });
    });

    test('update usa el callback de update con el id y el activo', () async {
      final cubit = crearCubit(Tela(
          id: 8,
          nombre: 'Seda',
          precxmen: 1,
          precxmay: 1,
          precxrollo: 1,
          precxcompra: 1));
      addTearDown(cubit.close);
      cubit.onActivoChanged(false);

      final ok = await cubit.onSubmit(isUpdate: true);

      expect(ok, true);
      expect(mapRecibido!['id'], 8);
      expect(mapRecibido!['activo'], false);
    });

    test('callback que lanza devuelve false', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      completarFormulario(cubit);
      lanzarError = true;

      expect(await cubit.onSubmit(isUpdate: false), false);
    });
  });
}
