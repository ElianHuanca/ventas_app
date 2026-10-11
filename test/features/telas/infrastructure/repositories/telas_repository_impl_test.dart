import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/infrastructure/repositories/telas_repository_impl.dart';

import '../../../../helpers/fake_datasources.dart';

void main() {
  late FakeTelasDatasource ds;
  late TelasRepositoryImpl repo;

  setUp(() {
    ds = FakeTelasDatasource();
    repo = TelasRepositoryImpl(ds);
  });

  test('getTelas respeta soloActivos (por defecto true)', () async {
    expect(await repo.getTelas(), same(ds.telas));
    expect(await repo.getTelas(soloActivos: false), same(ds.telas));
    expect(ds.llamadas, [
      ['getTelas', true],
      ['getTelas', false],
    ]);
  });

  test('getTelasPorSucursal filtra por la sucursal pedida', () async {
    expect(await repo.getTelasPorSucursal(4), same(ds.telas));
    expect(ds.llamadas, [
      ['getTelasPorSucursal', 4],
    ]);
  });

  test('getTela, createTela y updateTela', () async {
    final datos = {'nombre': 'Seda', 'precxmen': 30};

    expect(await repo.getTela(8), same(ds.tela));
    expect(await repo.createTela(datos), same(ds.tela));
    expect(await repo.updateTela(datos, 8), same(ds.tela));
    expect(ds.llamadas, [
      ['getTela', 8],
      ['createTela', datos],
      ['updateTela', datos, 8],
    ]);
  });

  test('colores de la tela: getColoresTela y setColorTela', () async {
    expect(await repo.getColoresTela(8), same(ds.colores));
    await repo.setColorTela(8, 2, true);
    expect(ds.llamadas, [
      ['getColoresTela', 8],
      ['setColorTela', 8, 2, true],
    ]);
  });

  test('no traga los errores del datasource', () async {
    final error = Exception('sin conexión');
    ds.error = error;
    final metodos = <String, Future<Object?> Function()>{
      'getTelas': () => repo.getTelas(),
      'getTelasPorSucursal': () => repo.getTelasPorSucursal(1),
      'getTela': () => repo.getTela(1),
      'createTela': () => repo.createTela({}),
      'updateTela': () => repo.updateTela({}, 1),
      'getColoresTela': () => repo.getColoresTela(1),
      'setColorTela': () => repo.setColorTela(1, 1, true),
    };

    for (final MapEntry(key: metodo, value: llamar) in metodos.entries) {
      await expectLater(llamar(), throwsA(same(error)), reason: metodo);
    }
    expect(ds.llamadas.map((l) => l.first), metodos.keys);
  });
}
