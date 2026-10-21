import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';

import '../../helpers/fake_repositories.dart';

void main() {
  const colores = [
    ColorItem(id: 1, nombre: 'Blanco', hex: 'FFFFFF'),
    ColorItem(id: 2, nombre: 'Negro', hex: '000000'),
  ];

  group('ColorFormCubit.normalizarHex', () {
    test('acepta 6 dígitos con o sin # y normaliza a mayúsculas sin #', () {
      expect(ColorFormCubit.normalizarHex('c0392b'), 'C0392B');
      expect(ColorFormCubit.normalizarHex('#FF00FF'), 'FF00FF');
    });

    test('rechaza largos y caracteres inválidos', () {
      expect(ColorFormCubit.normalizarHex('123'), isNull);
      expect(ColorFormCubit.normalizarHex('GGGGGG'), isNull);
      expect(ColorFormCubit.normalizarHex(''), isNull);
    });

    // Caso mínimo de test/propiedades/colores_propiedades_test.dart
    test('rechaza signos que int.parse acepta (+00000, -ABCDE)', () {
      expect(ColorFormCubit.normalizarHex('+00000'), isNull);
      expect(ColorFormCubit.normalizarHex('#-ABCDE'), isNull);
      // "ﬀ" (una letra) pasa a "FF" en mayúsculas
      expect(ColorFormCubit.normalizarHex('ﬀ1234'), isNull);
    });
  });

  group('ColorFormCubit', () {
    late FakeColoresRepository repo;

    setUp(() => repo = FakeColoresRepository());

    ColorFormCubit crearCubit([ColorItem? color]) => ColorFormCubit(
          onCreateCallback: (m) async {
            await repo.createColor(m);
            return true;
          },
          onUpdateCallback: (m) async {
            await repo.updateColor(m, m['id'] as int);
            return true;
          },
          onDeleteCallback: repo.deleteColor,
          color: color ?? const ColorItem(id: 0, nombre: ''),
        );

    test('estado inicial precarga el color', () {
      final cubit = crearCubit(colores.first);
      addTearDown(cubit.close);

      expect(cubit.state.id, 1);
      expect(cubit.state.nombre, 'Blanco');
      expect(cubit.state.hex, 'FFFFFF');
    });

    test('submit con nombre vacío devuelve false sin llamar al repo', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      cubit.onHexChanged('FF0000');

      expect(await cubit.onSubmit(isUpdate: false), false);
      expect(repo.creado, isNull);
    });

    test('submit con hex inválido devuelve false sin llamar al repo', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      cubit.onNombreChanged('Rojo');
      cubit.onHexChanged('xyz');

      expect(await cubit.onSubmit(isUpdate: false), false);
      expect(repo.creado, isNull);
    });

    test('create envía nombre con trim y hex normalizado', () async {
      final cubit = crearCubit();
      addTearDown(cubit.close);
      cubit.onNombreChanged('  Palo de rosa ');
      cubit.onHexChanged('#ff69b4');

      final ok = await cubit.onSubmit(isUpdate: false);

      expect(ok, true);
      expect(repo.creado, {'id': 0, 'nombre': 'Palo de rosa', 'hex': 'FF69B4'});
    });

    test('update usa el id existente', () async {
      final cubit = crearCubit(colores.first);
      addTearDown(cubit.close);
      cubit.onNombreChanged('Blanco humo');

      final ok = await cubit.onSubmit(isUpdate: true);

      expect(ok, true);
      expect(repo.actualizado!['id'], 1);
    });

    test('delete llama al repo con el id', () async {
      final cubit = crearCubit(colores.first);
      addTearDown(cubit.close);

      expect(await cubit.onDelete(), true);
      expect(repo.eliminado, 1);
    });
  });

  group('ColoresBloc', () {
    late FakeColoresRepository repo;

    setUp(() => repo = FakeColoresRepository(colores: colores));

    Future<ColoresBloc> crearBloc() async {
      final bloc = ColoresBloc(coloresRepository: repo);
      await pumpEventQueue();
      return bloc;
    }

    test('carga la lista de colores', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);

      expect(bloc.state.isLoading, false);
      expect(bloc.state.colores, colores);
    });

    test('isLoading queda en true mientras espera al repositorio', () async {
      final pendiente = _ColoresConCargaPendiente();
      final bloc = ColoresBloc(coloresRepository: pendiente);
      addTearDown(bloc.close);
      await pumpEventQueue();

      expect(bloc.state.isLoading, true);

      pendiente.carga.complete(colores);
      await pumpEventQueue();

      expect(bloc.state.isLoading, false);
      expect(bloc.state.colores, colores);
    });

    test('una recarga pedida mientras carga se ignora', () async {
      final pendiente = _ColoresConCargaPendiente();
      final bloc = ColoresBloc(coloresRepository: pendiente);
      addTearDown(bloc.close);
      await pumpEventQueue();

      bloc.add(ColoresLoadRequested());
      await pumpEventQueue();
      pendiente.carga.complete(colores);
      await pumpEventQueue();

      expect(pendiente.cargas, 1);
      expect(bloc.state.colores, colores);
    });

    test('createColor con error devuelve false y no toca la lista', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);
      repo.error = Exception('fallo');

      expect(
          await bloc.createColor({'nombre': 'Rojo', 'hex': 'FF0000'}), false);
      await pumpEventQueue();
      expect(bloc.state.colores, colores);
    });

    test('updateColor con error devuelve false y no toca la lista', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);
      repo.error = Exception('fallo');

      expect(
          await bloc
              .updateColor({'id': 1, 'nombre': 'Blanco humo', 'hex': 'F5F5F5'}),
          false);
      await pumpEventQueue();
      expect(bloc.state.colores, colores);
    });

    test('deleteColor con error del repositorio devuelve false', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);
      repo.error = Exception('fallo');

      expect(await bloc.deleteColor(2), false);
      await pumpEventQueue();
      expect(bloc.state.colores, colores);
    });

    test('createColor agrega al estado', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);

      final ok = await bloc.createColor({'nombre': 'Rojo', 'hex': 'FF0000'});
      await pumpEventQueue();

      expect(ok, true);
      expect(bloc.state.colores.length, 3);
      expect(bloc.state.colores.first.nombre, 'Rojo');
    });

    test('updateColor reemplaza en el estado', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);

      final ok = await bloc
          .updateColor({'id': 1, 'nombre': 'Blanco humo', 'hex': 'F5F5F5'});
      await pumpEventQueue();

      expect(ok, true);
      expect(bloc.state.colores.first.nombre, 'Blanco humo');
    });

    test('deleteColor quita del estado', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);

      final ok = await bloc.deleteColor(2);
      await pumpEventQueue();

      expect(ok, true);
      expect(bloc.state.colores.map((e) => e.id), [1]);
    });

    test('deleteColor fallido no cambia el estado', () async {
      final bloc = await crearBloc();
      addTearDown(bloc.close);
      repo.deleteResult = false;

      final ok = await bloc.deleteColor(2);

      expect(ok, false);
      expect(bloc.state.colores.length, 2);
    });
  });
}

/// Deja la carga de colores en espera hasta completar [carga] y cuenta las
/// cargas pedidas al repositorio.
class _ColoresConCargaPendiente extends FakeColoresRepository {
  final carga = Completer<List<ColorItem>>();
  int cargas = 0;

  @override
  Future<List<ColorItem>> getColores({bool soloActivos = true}) {
    cargas++;
    return carga.future;
  }
}
