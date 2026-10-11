import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/repositories/ventas_apliques_repository_impl.dart';

import '../../../../helpers/fake_datasources.dart';

void main() {
  late FakeVentasApliquesDatasource ds;
  late VentasApliquesRepositoryImpl repo;

  setUp(() {
    ds = FakeVentasApliquesDatasource();
    repo = VentasApliquesRepositoryImpl(ds);
  });

  test('createVentaAplique pasa totales y líneas tal cual y devuelve el id',
      () async {
    final detalles = [
      {
        'idapliques': 1,
        'idcolor': 2,
        'nombre': 'Flor (Rojo)',
        'precio': 12.0,
        'cantidad': 2.0,
        'total': 24.0,
        'ganancias': 14.0,
      },
    ];

    final id = await repo.createVentaAplique(
      idsucursales: 3,
      total: 24,
      ganancias: 14,
      descuento: 1.5,
      detalles: detalles,
    );

    expect(id, ds.idventa);
    expect(ds.llamadas, [
      ['createVentaAplique', 3, 24.0, 14.0, 1.5, detalles],
    ]);
  });

  test('getVentasApliques es de la sucursal pedida', () async {
    expect(await repo.getVentasApliques(5), same(ds.ventas));
    expect(ds.llamadas, [
      ['getVentasApliques', 5],
    ]);
  });

  test('getDetalleVentasApliques es de la venta pedida', () async {
    expect(await repo.getDetalleVentasApliques(42), same(ds.detalle));
    expect(ds.llamadas, [
      ['getDetalleVentasApliques', 42],
    ]);
  });

  test('no traga los errores (p. ej. stock insuficiente de la RPC)', () async {
    final error = Exception('Stock insuficiente');
    ds.error = error;

    await expectLater(
        repo.createVentaAplique(
            idsucursales: 1,
            total: 0,
            ganancias: 0,
            descuento: 0,
            detalles: const []),
        throwsA(same(error)));
    await expectLater(repo.getVentasApliques(1), throwsA(same(error)));
    await expectLater(repo.getDetalleVentasApliques(1), throwsA(same(error)));
  });
}
