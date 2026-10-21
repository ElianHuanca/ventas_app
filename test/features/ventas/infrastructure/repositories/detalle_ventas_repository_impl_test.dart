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

  test('borrarDetalleVenta devuelve la venta con el total ya descontado',
      () async {
    final venta = await repo.borrarDetalleVenta(9);

    expect(venta, same(ds.ventaTrasBorrar));
    expect(ds.llamadas, [
      ['borrarDetalleVenta', 9],
    ]);
  });

  test('borrarDetalleVenta de una línea que ya no estaba devuelve null',
      () async {
    ds.ventaTrasBorrar = null;

    expect(await repo.borrarDetalleVenta(9), isNull);
  });

  test('no traga los errores del datasource', () async {
    final error = Exception('sin conexión');
    ds.error = error;

    await expectLater(repo.getDetalleVenta(1), throwsA(same(error)));
    await expectLater(
        repo.createDetalleVenta(const [], 1), throwsA(same(error)));
    await expectLater(repo.borrarDetalleVenta(1), throwsA(same(error)));
  });
}
