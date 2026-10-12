import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/ventas/infrastructure/repositories/ventas_repository_impl.dart';

import '../../../../helpers/fake_datasources.dart';

void main() {
  late FakeVentasDatasource ds;
  late VentasRepositoryImpl repo;

  setUp(() {
    ds = FakeVentasDatasource();
    repo = VentasRepositoryImpl(ds);
  });

  test('getVentas y getVenta', () async {
    expect(await repo.getVentas(1), same(ds.ventas));
    expect(await repo.getVenta(2), same(ds.venta));
    expect(ds.llamadas, [
      ['getVentas', 1],
      ['getVenta', 2],
    ]);
  });

  test('getVentaByFecha devuelve null si ese día no tiene venta', () async {
    final fecha = DateTime(2026, 10, 3);

    expect(await repo.getVentaByFecha(1, fecha), isNull);
    ds.ventaByFecha = ds.venta;
    expect(await repo.getVentaByFecha(1, fecha), same(ds.venta));
    expect(ds.llamadas, [
      ['getVentaByFecha', 1, fecha],
      ['getVentaByFecha', 1, fecha],
    ]);
  });

  test('createVenta conserva la fecha elegida y createVentaAhora no la pide',
      () async {
    final fecha = DateTime(2026, 9, 30);

    expect(await repo.createVenta(3, fecha), same(ds.venta));
    expect(await repo.createVentaAhora(3), same(ds.venta));
    expect(ds.llamadas, [
      ['createVenta', 3, fecha],
      ['createVentaAhora', 3],
    ]);
  });

  test('actualizarVenta pasa los deltas sin tocarlos (convención incremental)',
      () async {
    final deltas = {'total': -25.0, 'ganancias': -10.0, 'descuento': 0};

    expect(await repo.actualizarVenta(deltas, 2), same(ds.venta));
    expect(ds.llamadas, [
      ['actualizarVenta', deltas, 2],
    ]);
  });

  test('deleteVenta', () async {
    await repo.deleteVenta(2);
    expect(ds.llamadas, [
      ['deleteVenta', 2],
    ]);
  });

  test('no traga los errores del datasource', () async {
    final error = Exception('sin conexión');
    ds.error = error;
    final metodos = <String, Future<Object?> Function()>{
      'getVentas': () => repo.getVentas(1),
      'getVenta': () => repo.getVenta(1),
      'getVentaByFecha': () => repo.getVentaByFecha(1, DateTime(2026)),
      'createVentaAhora': () => repo.createVentaAhora(1),
      'createVenta': () => repo.createVenta(1, DateTime(2026)),
      'actualizarVenta': () => repo.actualizarVenta({}, 1),
      'deleteVenta': () => repo.deleteVenta(1),
    };

    for (final MapEntry(key: metodo, value: llamar) in metodos.entries) {
      await expectLater(llamar(), throwsA(same(error)), reason: metodo);
    }
    expect(ds.llamadas.map((l) => l.first), metodos.keys);
  });
}
