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
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo', hex: '#FF0000', vinculado: true),
    ColorItem(id: 2, nombre: 'Verde', vinculado: false),
    ColorItem(id: 3, nombre: 'Azul', hex: '#0000FF', vinculado: true),
  ];
  const stockCentro = [
    StockAplique(
        apliqueId: 1, colorId: 1, colorNombre: 'Rojo', hex: '#FF0000', stock: 7),
  ];

  setUp(() {
    repo = FakeApliquesRepository(
      apliques: apliques,
      colores: colores,
      stock: stockCentro,
    );
  });

  Future<ProduccionFormCubit> crearCubit() async {
    final cubit = ProduccionFormCubit(apliquesRepository: repo);
    await pumpEventQueue();
    return cubit;
  }

  group('load', () {
    test('carga los apliques al crearse', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isLoading, false);
      expect(cubit.state.apliques, apliques);
    });

    test('error del repositorio deja isLoading en false', () async {
      repo.error = Exception('fallo');
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isLoading, false);
      expect(cubit.state.apliques, isEmpty);
    });
  });

  group('onSucursalChanged', () {
    test('carga el stock de la sucursal y limpia selección previa', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      await cubit.onApliqueChanged(apliques[0]);

      await cubit.onSucursalChanged(1);

      expect(repo.lastGetStockSucursalId, 1);
      expect(cubit.state.stock, stockCentro);
      expect(cubit.state.idapliques, 0);
      expect(cubit.state.idcolor, 0);
      expect(cubit.state.colores, isEmpty);
    });

    test('con sucursal 0 no consulta stock', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.onSucursalChanged(0);

      expect(repo.getStockCalls, 0);
      expect(cubit.state.stock, isEmpty);
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

  group('stockActual', () {
    test('devuelve el stock del aplique+color seleccionados', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      await cubit.onSucursalChanged(1);
      await cubit.onApliqueChanged(apliques[0]);

      cubit.onColorChanged(colores[0]); // Rojo, stock 7
      expect(cubit.state.stockActual, 7);

      cubit.onColorChanged(colores[2]); // Azul, sin fila de inventario
      expect(cubit.state.stockActual, 0);
    });
  });

  group('registrar', () {
    test('valida sucursal, aplique, color y cantidad', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(await cubit.registrar(), 'Seleccione una sucursal');

      await cubit.onSucursalChanged(1);
      expect(await cubit.registrar(), 'Seleccione un aplique');

      await cubit.onApliqueChanged(apliques[0]);
      expect(await cubit.registrar(), 'Seleccione un color');

      cubit.onColorChanged(colores[0]);
      expect(
          await cubit.registrar(), 'Ingrese una cantidad válida mayor a 0');

      cubit.onCantidadChanged('abc');
      expect(
          await cubit.registrar(), 'Ingrese una cantidad válida mayor a 0');

      cubit.onCantidadChanged('-2');
      expect(
          await cubit.registrar(), 'Ingrese una cantidad válida mayor a 0');
    });

    test('válido crea producción, refresca stock y limpia cantidad',
        () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      await cubit.onSucursalChanged(1);
      await cubit.onApliqueChanged(apliques[0]);
      cubit.onColorChanged(colores[0]);
      cubit.onCantidadChanged('3');
      const stockActualizado = [
        StockAplique(
            apliqueId: 1,
            colorId: 1,
            colorNombre: 'Rojo',
            hex: '#FF0000',
            stock: 10),
      ];
      repo.stock = stockActualizado;

      final error = await cubit.registrar();

      expect(error, isNull);
      expect(repo.produccionesCreadas.single, {
        'sucursalId': 1,
        'apliqueId': 1,
        'colorId': 1,
        'cantidad': 3.0,
      });
      expect(cubit.state.stock, stockActualizado);
      expect(cubit.state.cantidad, '');
      expect(cubit.state.isSubmitting, false);
    });

    test('error del repositorio devuelve mensaje sin prefijo Exception:',
        () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.onSucursalChanged(1);
      await cubit.onApliqueChanged(apliques[0]);
      cubit.onColorChanged(colores[0]);
      cubit.onCantidadChanged('3');
      repo.error = Exception('stock negativo');

      final error = await cubit.registrar();

      expect(error, 'stock negativo');
      expect(cubit.state.isSubmitting, false);
    });
  });
}
