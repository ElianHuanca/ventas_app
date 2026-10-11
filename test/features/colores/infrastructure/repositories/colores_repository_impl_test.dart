import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/colores/infrastructure/repositories/colores_repository_impl.dart';

import '../../../../helpers/fake_datasources.dart';

void main() {
  late FakeColoresDatasource ds;
  late ColoresRepositoryImpl repo;

  setUp(() {
    ds = FakeColoresDatasource();
    repo = ColoresRepositoryImpl(ds);
  });

  test('getColores respeta soloActivos (por defecto true)', () async {
    expect(await repo.getColores(), same(ds.colores));
    expect(await repo.getColores(soloActivos: false), same(ds.colores));
    expect(ds.llamadas, [
      ['getColores', true],
      ['getColores', false],
    ]);
  });

  test('createColor y updateColor pasan el mapa y el id', () async {
    final datos = {'nombre': 'Azul', 'hex': '0000FF'};

    expect(await repo.createColor(datos), same(ds.color));
    expect(await repo.updateColor(datos, 9), same(ds.color));
    expect(ds.llamadas, [
      ['createColor', datos],
      ['updateColor', datos, 9],
    ]);
  });

  test('deleteColor devuelve lo que informa el datasource', () async {
    expect(await repo.deleteColor(4), isTrue);
    ds.eliminado = false;
    expect(await repo.deleteColor(5), isFalse);
    expect(ds.llamadas, [
      ['deleteColor', 4],
      ['deleteColor', 5],
    ]);
  });

  test('no traga los errores del datasource', () async {
    final error = Exception('sin conexión');
    ds.error = error;

    await expectLater(repo.getColores(), throwsA(same(error)));
    await expectLater(repo.createColor({}), throwsA(same(error)));
    await expectLater(repo.updateColor({}, 1), throwsA(same(error)));
    await expectLater(repo.deleteColor(1), throwsA(same(error)));
  });
}
