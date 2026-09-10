import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/produccion_form_cubit.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeApliquesRepository repo;

  final apliques = [
    Aplique(id: 1, nombre: 'Flor'),
    Aplique(id: 2, nombre: 'Luna'),
  ];
  const produccionesIniciales = [
    Produccion(
      id: 1,
      fecha: '2024-01-01',
      sucursalNombre: 'Centro',
      apliqueNombre: 'Flor',
      colorNombre: 'Rojo',
      cantidad: 5,
    ),
  ];
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo', vinculado: true),
    ColorItem(id: 2, nombre: 'Verde', vinculado: false),
    ColorItem(id: 3, nombre: 'Azul', vinculado: true),
  ];

  setUp(() {
    repo = FakeApliquesRepository(
      apliques: apliques,
      colores: colores,
      producciones: produccionesIniciales,
    );
  });

  Future<ProduccionFormCubit> crearCubit() async {
    final cubit = ProduccionFormCubit(apliquesRepository: repo);
    await pumpEventQueue();
    return cubit;
  }

  group('load', () {
    test('carga apliques y producciones al crearse', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isLoading, false);
      expect(cubit.state.apliques, apliques);
      expect(cubit.state.producciones, produccionesIniciales);
    });

    test('error del repositorio deja isLoading en false', () async {
      repo.error = Exception('fallo');
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isLoading, false);
      expect(cubit.state.apliques, isEmpty);
    });
  });

  group('onApliqueChanged', () {
    test('carga solo los colores vinculados al aplique', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.onApliqueChanged(apliques[0]);

      expect(repo.lastGetColoresApliqueId, 1);
      expect(cubit.state.colores.map((e) => e.id), [1, 3]);
    });

    test('con null limpia selección y no consulta colores', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.onApliqueChanged(null);

      expect(cubit.state.idapliques, 0);
      expect(cubit.state.colores, isEmpty);
      expect(repo.lastGetColoresApliqueId, isNull);
    });
  });

  group('registrar', () {
    test('valida sucursal, aplique, color y cantidad', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(await cubit.registrar(), 'Seleccione una sucursal');

      cubit.onSucursalChanged(1);
      expect(await cubit.registrar(), 'Seleccione un aplique');

      await cubit.onApliqueChanged(apliques[0]);
      expect(await cubit.registrar(), 'Seleccione un color');

      cubit.onColorChanged(const ColorItem(id: 1, nombre: 'Rojo'));
      expect(
          await cubit.registrar(), 'Ingrese una cantidad válida mayor a 0');

      cubit.onCantidadChanged('abc');
      expect(
          await cubit.registrar(), 'Ingrese una cantidad válida mayor a 0');

      cubit.onCantidadChanged('-2');
      expect(
          await cubit.registrar(), 'Ingrese una cantidad válida mayor a 0');
    });

    test('válido crea producción, refresca historial y limpia cantidad',
        () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      const nuevaProduccion = Produccion(
        id: 2,
        fecha: '2024-02-01',
        sucursalNombre: 'Centro',
        apliqueNombre: 'Flor',
        colorNombre: 'Rojo',
        cantidad: 3,
      );

      cubit.onSucursalChanged(1);
      await cubit.onApliqueChanged(apliques[0]);
      cubit.onColorChanged(const ColorItem(id: 1, nombre: 'Rojo'));
      cubit.onCantidadChanged('3');
      repo.producciones = const [nuevaProduccion];

      final error = await cubit.registrar();

      expect(error, isNull);
      expect(repo.produccionesCreadas.single, {
        'sucursalId': 1,
        'apliqueId': 1,
        'colorId': 1,
        'cantidad': 3.0,
      });
      expect(cubit.state.producciones, [nuevaProduccion]);
      expect(cubit.state.cantidad, '');
      expect(cubit.state.isSubmitting, false);
    });

    test('error del repositorio devuelve mensaje sin prefijo Exception:',
        () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      cubit.onSucursalChanged(1);
      await cubit.onApliqueChanged(apliques[0]);
      cubit.onColorChanged(const ColorItem(id: 1, nombre: 'Rojo'));
      cubit.onCantidadChanged('3');
      repo.error = Exception('stock negativo');

      final error = await cubit.registrar();

      expect(error, 'stock negativo');
      expect(cubit.state.isSubmitting, false);
    });
  });
}
