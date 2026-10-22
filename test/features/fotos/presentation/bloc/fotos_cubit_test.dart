import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/fotos/fotos.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeFotosRepository repo;

  const fotos = [
    Foto(id: 1, url: 'https://example.com/1.jpg'),
    Foto(id: 2, url: 'https://example.com/2.jpg'),
  ];
  const elegida = FotoElegida(bytes: [1, 2, 3], extension: 'jpg');

  setUp(() {
    repo = FakeFotosRepository(nombre: 'Lino', fotos: fotos);
  });

  Future<FotosCubit> crearCubit(
      {ProductoConFotos producto = ProductoConFotos.tela}) async {
    final cubit = FotosCubit(fotosRepository: repo, producto: producto, id: 7);
    addTearDown(cubit.close);
    await pumpEventQueue();
    return cubit;
  }

  test('al crearse carga el nombre y las fotos del producto', () async {
    final cubit = await crearCubit(producto: ProductoConFotos.aplique);

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.error, isFalse);
    expect(cubit.state.nombre, 'Lino');
    expect(cubit.state.fotos, fotos);
    expect(repo.getFotosCalls, [(ProductoConFotos.aplique, 7)]);
  });

  test('si la carga falla marca error; reintentar lo recupera', () async {
    repo.error = Exception('sin conexión');
    final cubit = await crearCubit();

    expect(cubit.state.error, isTrue);
    expect(cubit.state.isLoading, isFalse);

    repo.error = null;
    await cubit.cargar();

    expect(cubit.state.error, isFalse);
    expect(cubit.state.fotos, fotos);
  });

  test('subir agrega la foto al final y avisa que salió bien', () async {
    final cubit = await crearCubit();

    final subio = await cubit.subir(elegida);

    expect(subio, isTrue);
    expect(cubit.state.subiendo, isFalse);
    expect(cubit.state.fotos, hasLength(3));
    expect(cubit.state.fotos.first, fotos.first,
        reason: 'la principal sigue siendo la primera');
    expect(repo.subirCalls.single, (ProductoConFotos.tela, 7, elegida));
  });

  test('mientras sube marca subiendo y no deja subir otra a la vez',
      () async {
    final cubit = await crearCubit();
    final lento = Completer<void>();
    final repoLento = _RepoLento(repo, lento.future);
    final cubitLento = FotosCubit(
        fotosRepository: repoLento, producto: ProductoConFotos.tela, id: 7);
    addTearDown(cubitLento.close);
    await pumpEventQueue();

    final primera = cubitLento.subir(elegida);
    await pumpEventQueue();
    expect(cubitLento.state.subiendo, isTrue);
    expect(await cubitLento.subir(elegida), isFalse);

    lento.complete();
    expect(await primera, isTrue);
    expect(cubitLento.state.subiendo, isFalse);
    expect(repo.subirCalls, hasLength(1));
    expect(cubit.state.fotos, hasLength(2));
  });

  test('si subir falla no agrega nada y devuelve false', () async {
    final cubit = await crearCubit();
    repo.errorAlSubir = Exception('muy grande');

    final subio = await cubit.subir(elegida);

    expect(subio, isFalse);
    expect(cubit.state.subiendo, isFalse);
    expect(cubit.state.fotos, fotos);
  });

  test('quitar la saca de la lista (baja lógica en el repositorio)', () async {
    final cubit = await crearCubit();

    final quito = await cubit.quitar(1);

    expect(quito, isTrue);
    expect(cubit.state.fotos, [fotos.last]);
    expect(repo.quitarCalls, [(ProductoConFotos.tela, 1)]);
  });

  test('si quitar falla la foto sigue en la lista', () async {
    final cubit = await crearCubit();
    repo.error = Exception('sin conexión');

    final quito = await cubit.quitar(1);

    expect(quito, isFalse);
    expect(cubit.state.fotos, fotos);
  });
}

/// Sube recién cuando se completa [espera].
class _RepoLento extends FakeFotosRepository {
  final FakeFotosRepository base;
  final Future<void> espera;

  _RepoLento(this.base, this.espera)
      : super(nombre: base.nombre, fotos: base.fotos);

  @override
  Future<Foto> subirFoto(
      ProductoConFotos producto, int id, FotoElegida foto) async {
    await espera;
    return base.subirFoto(producto, id, foto);
  }
}
