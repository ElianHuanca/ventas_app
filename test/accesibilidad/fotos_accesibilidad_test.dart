import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/fotos/fotos.dart';

import '../helpers/fake_repositories.dart';
import '../helpers/imagenes.dart';
import 'accesibilidad_helpers.dart';

void main() {
  const fotos = [
    Foto(id: 1, url: 'https://example.com/a11y-1.jpg'),
    Foto(id: 2, url: 'https://example.com/a11y-2.jpg'),
  ];

  Future<void> montar(WidgetTester tester, FakeFotosRepository repo) async {
    liberarImagenesAlTerminar(tester);
    final cubit = FotosCubit(
        fotosRepository: repo, producto: ProductoConFotos.tela, id: 1);
    addTearDown(cubit.close);
    await montarPantalla(
      tester,
      BlocProvider.value(
        value: cubit,
        child: FotosScreen(
          producto: ProductoConFotos.tela,
          conCamara: true,
          imagen: imagenDePrueba,
        ),
      ),
    );
    // Termina de decodificar las imágenes (fuera del reloj falso)
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
  }

  group('/tela-fotos/:idtela y /aplique-fotos/:idaplique (FotosScreen)', () {
    verificarGuias(
        'con fotos',
        (tester) =>
            montar(tester, FakeFotosRepository(nombre: 'Lino', fotos: fotos)));
    verificarGuias('sin fotos',
        (tester) => montar(tester, FakeFotosRepository(nombre: 'Lino')));
    verificarGuias(
        'sin conexión',
        (tester) =>
            montar(tester, FakeFotosRepository()..error = Exception('red')));
  });
}
