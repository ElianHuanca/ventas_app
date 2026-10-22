@Tags(['golden'])
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/fotos/fotos.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/imagenes.dart';
import '../fotos/fotos_screen_golden_test.dart' show esperarImagenes, fotos;
import 'chica_helpers.dart';

// `/tela-fotos/:id` y `/aplique-fotos/:id` (la misma pantalla).
void main() {
  testWidgets('fotos de un aplique de nombre largo', (tester) async {
    final cubit = FotosCubit(
      fotosRepository: FakeFotosRepository(
          nombre: 'Flor Petalo Suizo Grande - Bolsa x100 und', fotos: fotos),
      producto: ProductoConFotos.aplique,
      id: 7,
    );
    addTearDown(cubit.close);
    await montarChica(
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

    await compararChica('fotos');
  });
}
