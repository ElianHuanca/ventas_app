import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/fotos/fotos.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/imagenes.dart';
import '../fotos/fotos_screen_golden_test.dart' show esperarImagenes, fotos;
import '../golden_helpers.dart';

/// `/tela-fotos/:id` y `/aplique-fotos/:id` (la misma pantalla).
void capturasDeFotos(
  Dispositivo d, {
  bool todosLosEstados = false,
  Set<String> omitidas = const {},
}) {
  Future<void> montar(WidgetTester tester, FakeFotosRepository repo) async {
    final cubit = FotosCubit(
      fotosRepository: repo,
      producto: ProductoConFotos.aplique,
      id: 7,
    );
    addTearDown(cubit.close);
    await d.montar(
      tester,
      BlocProvider.value(
        value: cubit,
        child: FotosScreen(
          producto: ProductoConFotos.aplique,
          conCamara: true,
          imagen: imagenDePrueba,
        ),
      ),
    );
    await esperarImagenes(tester);
  }

  testWidgets('fotos de un aplique de nombre largo',
      skip: omitidas.contains('fotos'), (tester) async {
    await montar(
        tester,
        FakeFotosRepository(
            nombre: 'Flor Petalo Suizo Grande - Bolsa x100 und',
            fotos: fotos));

    await d.comparar('fotos');
  });

  if (todosLosEstados) {
    testWidgets('aplique sin fotos', skip: omitidas.contains('fotos_vacia'),
        (tester) async {
      await montar(tester, FakeFotosRepository(nombre: 'Flor bordada 10x10'));

      await d.comparar('fotos_vacia');
    });
  }
}
