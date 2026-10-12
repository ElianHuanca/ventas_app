import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/infrastructure/repositories/sucursales_repository_impl.dart';

import '../../../../helpers/fake_datasources.dart';

void main() {
  late FakeSucursalesDatasource ds;
  late SucursalesRepositoryImpl repo;

  setUp(() {
    ds = FakeSucursalesDatasource();
    repo = SucursalesRepositoryImpl(ds);
  });

  test('getSucursales y getSucursal', () async {
    expect(await repo.getSucursales(), same(ds.sucursales));
    expect(await repo.getSucursal(5), same(ds.sucursal));
    expect(ds.llamadas, [
      ['getSucursales'],
      ['getSucursal', 5],
    ]);
  });

  test('createSucursal y updateSucursal pasan el mapa y el id', () async {
    final datos = {'nombre': 'Norte'};

    expect(await repo.createSucursal(datos), same(ds.sucursal));
    expect(await repo.updateSucursal(datos, 5), same(ds.sucursal));
    expect(ds.llamadas, [
      ['createSucursal', datos],
      ['updateSucursal', datos, 5],
    ]);
  });

  test('deleteSucursal devuelve lo que informa el datasource', () async {
    expect(await repo.deleteSucursal(5), isTrue);
    ds.eliminada = false;
    expect(await repo.deleteSucursal(6), isFalse);
    expect(ds.llamadas, [
      ['deleteSucursal', 5],
      ['deleteSucursal', 6],
    ]);
  });

  test('disponibilidad: getTelasSucursal y setTelaSucursal (tela, sucursal)',
      () async {
    expect(await repo.getTelasSucursal(2), same(ds.telasSucursal));
    await repo.setTelaSucursal(3, 2, false);
    expect(ds.llamadas, [
      ['getTelasSucursal', 2],
      ['setTelaSucursal', 3, 2, false],
    ]);
  });

  test('no traga los errores del datasource', () async {
    final error = Exception('sin conexión');
    ds.error = error;
    final metodos = <String, Future<Object?> Function()>{
      'getSucursales': () => repo.getSucursales(),
      'getSucursal': () => repo.getSucursal(1),
      'createSucursal': () => repo.createSucursal({}),
      'updateSucursal': () => repo.updateSucursal({}, 1),
      'deleteSucursal': () => repo.deleteSucursal(1),
      'getTelasSucursal': () => repo.getTelasSucursal(1),
      'setTelaSucursal': () => repo.setTelaSucursal(1, 1, true),
    };

    for (final MapEntry(key: metodo, value: llamar) in metodos.entries) {
      await expectLater(llamar(), throwsA(same(error)), reason: metodo);
    }
    expect(ds.llamadas.map((l) => l.first), metodos.keys);
  });
}
