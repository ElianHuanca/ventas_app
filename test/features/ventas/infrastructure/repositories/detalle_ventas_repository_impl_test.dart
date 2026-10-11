import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/ventas/infrastructure/repositories/detalleVentas_repository_impl.dart';

import '../../../../helpers/fake_datasources.dart';

void main() {
  late FakeDetalleVentasDatasource ds;
  late DetalleVentasRepositoryImpl repo;

  setUp(() {
    ds = FakeDetalleVentasDatasource();
    repo = DetalleVentasRepositoryImpl(ds);
  });

  test('getDetalleVenta es de la venta pedida', () async {
    expect(await repo.getDetalleVenta(10), same(ds.detalles));
    expect(ds.llamadas, [
      ['getDetalleVenta', 10],
    ]);
  });

  test('createDetalleVenta pasa las líneas y la venta tal cual', () async {
    final lineas = [
      {
        'idtelas': 3,
        'nombre': 'Lino',
        'precio': 25.0,
        'cantidad': 2.0,
        'total': 50.0,
        'ganancias': 20.0,
      },
    ];

    expect(await repo.createDetalleVenta(lineas, 10), same(ds.detalles));
    expect(ds.llamadas, [
      ['createDetalleVenta', lineas, 10],
    ]);
  });

  test('deleteDetalleVenta devuelve la línea borrada (para descontar el total)',
      () async {
    final borrada = await repo.deleteDetalleVenta(9);

    expect(borrada, same(ds.borrado));
    expect(borrada.total, 30);
    expect(ds.llamadas, [
      ['deleteDetalleVenta', 9],
    ]);
  });

  test('no traga los errores del datasource', () async {
    final error = Exception('sin conexión');
    ds.error = error;

    await expectLater(repo.getDetalleVenta(1), throwsA(same(error)));
    await expectLater(
        repo.createDetalleVenta(const [], 1), throwsA(same(error)));
    await expectLater(repo.deleteDetalleVenta(1), throwsA(same(error)));
  });
}
