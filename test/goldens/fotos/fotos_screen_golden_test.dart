@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/fotos/fotos.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/imagenes.dart';
import '../golden_helpers.dart';

/// Fotos de prueba: imágenes en memoria (sin red), una por color.
const fotos = [
  Foto(id: 1, url: 'https://example.com/lino-1.jpg'),
  Foto(id: 2, url: 'https://example.com/lino-2.jpg'),
  Foto(id: 3, url: 'https://example.com/lino-3.jpg'),
];

/// Las imágenes en memoria se decodifican fuera del reloj falso de
/// flutter_test: se espera de verdad y se vuelve a dibujar.
Future<void> esperarImagenes(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pump();
}

void main() {
  Future<void> montar(
    WidgetTester tester,
    FotosRepository repo, {
    ProductoConFotos producto = ProductoConFotos.tela,
    bool asentar = true,
  }) async {
    final cubit = FotosCubit(fotosRepository: repo, producto: producto, id: 7);
    addTearDown(cubit.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: cubit,
        child: FotosScreen(
          producto: producto,
          conCamara: true,
          imagen: imagenDePrueba,
          elegirFoto: (_) async =>
              const FotoElegida(bytes: [1, 2, 3], extension: 'jpg'),
        ),
      ),
      asentar: asentar,
    );
    if (asentar) await esperarImagenes(tester);
  }

  testWidgets('fotos de la tela con la principal', (tester) async {
    await montar(tester, FakeFotosRepository(nombre: 'Lino', fotos: fotos));

    await compararCaptura('fotos_con_fotos');
  });

  testWidgets('aplique sin fotos', (tester) async {
    await montar(tester, FakeFotosRepository(nombre: 'Flor bordada 10x10'),
        producto: ProductoConFotos.aplique);

    await compararCaptura('fotos_sin_fotos');
  });

  testWidgets('subiendo una foto', (tester) async {
    final repo = _SubidaLenta(nombre: 'Lino', fotos: fotos.take(1).toList());
    try {
      await montar(tester, repo);
      await tester.tap(find.text('Galería'));
      await tester.pump();
      expect(find.text('Subiendo foto…'), findsOneWidget);

      await compararCaptura('fotos_subiendo');
    } finally {
      repo.espera.complete();
    }
  });

  testWidgets('sin conexión', (tester) async {
    await montar(tester, FakeFotosRepository()..error = Exception('red'));

    await compararCaptura('fotos_error');
  });

  testWidgets('cargando', (tester) async {
    final repo = _CargaLenta();
    try {
      await montar(tester, repo, asentar: false);
      await tester.pump(const Duration(milliseconds: 400));

      await compararCaptura('fotos_cargando');
    } finally {
      repo.espera.complete();
    }
  });
}

class _SubidaLenta extends FakeFotosRepository {
  final espera = Completer<void>();

  _SubidaLenta({super.nombre, super.fotos});

  @override
  Future<Foto> subirFoto(
      ProductoConFotos producto, int id, FotoElegida foto) async {
    await espera.future;
    return super.subirFoto(producto, id, foto);
  }
}

class _CargaLenta extends FakeFotosRepository {
  final espera = Completer<void>();

  @override
  Future<List<Foto>> getFotos(ProductoConFotos producto, int id) async {
    await espera.future;
    return super.getFotos(producto, id);
  }
}
