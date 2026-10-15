import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/repositories/apliques_repository_impl.dart';

import '../../../../helpers/fake_datasources.dart';

void main() {
  late FakeApliquesDatasource ds;
  late ApliquesRepositoryImpl repo;

  setUp(() {
    ds = FakeApliquesDatasource();
    repo = ApliquesRepositoryImpl(ds);
  });

  group('delega en el datasource con los mismos argumentos', () {
    test('getApliques respeta soloActivos (por defecto true)', () async {
      expect(await repo.getApliques(), same(ds.apliques));
      expect(await repo.getApliques(soloActivos: false), same(ds.apliques));
      expect(ds.llamadas, [
        ['getApliques', true],
        ['getApliques', false],
      ]);
    });

    test('createAplique y updateAplique pasan el mapa y el id', () async {
      final datos = {'nombre': 'Luna', 'costo_fabricacion': 5};

      expect(await repo.createAplique(datos), same(ds.aplique));
      expect(await repo.updateAplique(datos, 7), same(ds.aplique));
      expect(ds.llamadas, [
        ['createAplique', datos],
        ['updateAplique', datos, 7],
      ]);
    });

    test('getStock es de la sucursal pedida', () async {
      expect(await repo.getStock(3), same(ds.stock));
      expect(ds.llamadas, [
        ['getStock', 3],
      ]);
    });

    test('getInventarioConVentas pasa la sucursal y el rango', () async {
      final desde = DateTime(2026, 9, 18);
      final hasta = DateTime(2026, 10, 15);

      expect(
          await repo.getInventarioConVentas(2, desde: desde, hasta: hasta),
          same(ds.inventarioConVentas));
      expect(ds.llamadas, [
        ['getInventarioConVentas', 2, desde, hasta],
      ]);
    });

    test('getColores y getColoresAplique', () async {
      expect(await repo.getColores(), same(ds.colores));
      expect(await repo.getColoresAplique(4), same(ds.colores));
      expect(ds.llamadas, [
        ['getColores'],
        ['getColoresAplique', 4],
      ]);
    });

    test('setColorAplique pasa aplique, color y activo', () async {
      await repo.setColorAplique(1, 2, false);
      expect(ds.llamadas, [
        ['setColorAplique', 1, 2, false],
      ]);
    });

    test('addInventario y removeInventario en orden sucursal, aplique, color',
        () async {
      await repo.addInventario(1, 2, 3);
      await repo.removeInventario(1, 2, 3);
      expect(ds.llamadas, [
        ['addInventario', 1, 2, 3],
        ['removeInventario', 1, 2, 3],
      ]);
    });

    test('createProduccion pasa sucursal, fecha y líneas', () async {
      final fecha = DateTime(2026, 10, 5);
      final lineas = [
        {'idaplique': 1, 'idcolor': 2, 'cantidad': 3.0},
      ];

      await repo.createProduccion(sucursalId: 9, fecha: fecha, lineas: lineas);

      expect(ds.llamadas, [
        ['createProduccion', 9, fecha, lineas],
      ]);
    });

    test('getProducciones y getDetalleProduccion', () async {
      expect(await repo.getProducciones(2), same(ds.producciones));
      expect(await repo.getDetalleProduccion(3), same(ds.detalleProduccion));
      expect(ds.llamadas, [
        ['getProducciones', 2],
        ['getDetalleProduccion', 3],
      ]);
    });
  });

  test('no traga los errores del datasource: los blocs los necesitan',
      () async {
    final error = Exception('sin conexión');
    ds.error = error;
    final metodos = <String, Future<Object?> Function()>{
      'getApliques': () => repo.getApliques(),
      'createAplique': () => repo.createAplique({}),
      'updateAplique': () => repo.updateAplique({}, 1),
      'getStock': () => repo.getStock(1),
      'getColores': () => repo.getColores(),
      'getColoresAplique': () => repo.getColoresAplique(1),
      'setColorAplique': () => repo.setColorAplique(1, 1, true),
      'addInventario': () => repo.addInventario(1, 1, 1),
      'removeInventario': () => repo.removeInventario(1, 1, 1),
      'createProduccion': () => repo.createProduccion(
          sucursalId: 1, fecha: DateTime(2026), lineas: const []),
      'getProducciones': () => repo.getProducciones(1),
      'getDetalleProduccion': () => repo.getDetalleProduccion(1),
    };

    for (final MapEntry(key: metodo, value: llamar) in metodos.entries) {
      await expectLater(llamar(), throwsA(same(error)), reason: metodo);
    }
    expect(ds.llamadas.map((l) => l.first), metodos.keys);
  });
}
