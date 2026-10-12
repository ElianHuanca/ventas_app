@Tags(['golden'])
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/colores/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import 'chica_helpers.dart';

// `/colores` y `/color/:id`.
void main() {
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo carmesí', hex: 'C0392B'),
    ColorItem(id: 2, nombre: 'Azul marino', hex: '000080'),
    ColorItem(id: 3, nombre: 'Dorado', hex: 'D4AF37'),
    ColorItem(id: 4, nombre: 'Verde esmeralda', hex: '50C878'),
    ColorItem(id: 5, nombre: 'Coral', hex: 'FF7F50'),
    ColorItem(id: 6, nombre: 'Negro', hex: '000000'),
    ColorItem(id: 7, nombre: 'Blanco', hex: 'FFFFFF'),
  ];

  testWidgets('listado de colores', (tester) async {
    final bloc = ColoresBloc(
      coloresRepository: FakeColoresRepository(colores: colores),
    );
    addTearDown(bloc.close);
    await montarChica(
      tester,
      BlocProvider.value(value: bloc, child: const ColoresScreen()),
    );

    await compararChica('colores');
  });

  testWidgets('formulario del color (edición)', (tester) async {
    final bloc = ColoresBloc(
      coloresRepository: FakeColoresRepository(colores: colores),
    );
    addTearDown(bloc.close);
    await montarChica(
      tester,
      BlocProvider.value(value: bloc, child: const ColorScreen(id: 4)),
    );

    await compararChica('color_edicion');
  });
}
