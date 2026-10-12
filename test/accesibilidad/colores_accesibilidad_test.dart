import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/colores/presentation/screens/screens.dart';

import '../helpers/fake_repositories.dart';
import 'accesibilidad_helpers.dart';

void main() {
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo carmesí', hex: 'C0392B'),
    ColorItem(id: 2, nombre: 'Azul marino', hex: '000080'),
    ColorItem(id: 3, nombre: 'Dorado', hex: 'D4AF37'),
    ColorItem(id: 4, nombre: 'Blanco', hex: 'FFFFFF'),
  ];

  /// `/colores` y `/color/:id` usan el ColoresBloc de la ruta.
  Future<void> montar(WidgetTester tester, Widget Function() pantalla) {
    final bloc =
        ColoresBloc(coloresRepository: FakeColoresRepository(colores: colores));
    addTearDown(bloc.close);
    return montarPantalla(
      tester,
      BlocProvider.value(value: bloc, child: pantalla()),
    );
  }

  group('/colores (ColoresScreen)', () {
    verificarGuias('cada color con su muestra y su hex',
        (t) => montar(t, () => const ColoresScreen()));
  });

  group('/color/:idcolor (ColorScreen)', () {
    verificarGuias('alta', (t) => montar(t, () => const ColorScreen(id: 0)));
    verificarGuias('edición con vista previa',
        (t) => montar(t, () => const ColorScreen(id: 2)));
  });
}
