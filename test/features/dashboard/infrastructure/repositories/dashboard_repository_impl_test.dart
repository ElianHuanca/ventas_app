import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/dashboard/infrastructure/repositories/dashboard_repository_impl.dart';

import '../../../../helpers/fake_datasources.dart';

void main() {
  late FakeDashboardDatasource ds;
  late DashboardRepositoryImpl repo;
  final desde = DateTime(2026, 10, 1);
  final hasta = DateTime(2026, 10, 31);

  setUp(() {
    ds = FakeDashboardDatasource();
    repo = DashboardRepositoryImpl(ds);
  });

  test('cada RPC recibe el mismo rango (desde, hasta) sin invertirlo',
      () async {
    expect(await repo.getTopProductos(desde: desde, hasta: hasta),
        same(ds.topTelas));
    expect(await repo.getTopApliques(desde: desde, hasta: hasta),
        same(ds.topApliques));
    expect(await repo.getResumenVentas(desde: desde, hasta: hasta),
        same(ds.resumenTelas));
    expect(await repo.getResumenVentasApliques(desde: desde, hasta: hasta),
        same(ds.resumenApliques));

    expect(ds.llamadas, [
      ['getTopProductos', desde, hasta],
      ['getTopApliques', desde, hasta],
      ['getResumenVentas', desde, hasta],
      ['getResumenVentasApliques', desde, hasta],
    ]);
  });

  test('telas y apliques no se cruzan', () async {
    final telas = await repo.getTopProductos(desde: desde, hasta: hasta);
    final apliques = await repo.getTopApliques(desde: desde, hasta: hasta);

    expect(telas.single.nombre, 'Lino');
    expect(apliques.single.nombre, 'Flor');
  });

  test('no traga los errores de las RPC', () async {
    final error = Exception('sin conexión');
    ds.error = error;

    await expectLater(
        repo.getTopProductos(desde: desde, hasta: hasta), throwsA(same(error)));
    await expectLater(
        repo.getTopApliques(desde: desde, hasta: hasta), throwsA(same(error)));
    await expectLater(repo.getResumenVentas(desde: desde, hasta: hasta),
        throwsA(same(error)));
    await expectLater(repo.getResumenVentasApliques(desde: desde, hasta: hasta),
        throwsA(same(error)));
  });
}
