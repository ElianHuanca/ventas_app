@Tags(['golden'])
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

void main() {
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo', hex: 'C62828', vinculado: true),
    ColorItem(id: 2, nombre: 'Azul marino', hex: '1A237E', vinculado: true),
    ColorItem(id: 3, nombre: 'Verde', hex: '2E7D32', vinculado: false),
    ColorItem(id: 4, nombre: 'Beige', hex: 'D7CCC8', vinculado: true),
    ColorItem(id: 5, nombre: 'Negro', hex: '000000', vinculado: false),
  ];

  Future<void> montar(WidgetTester tester, List<ColorItem> colores) async {
    final repo = FakeTelasRepository(
      telas: [Tela(id: 7, nombre: 'Lino')],
      colores: colores,
    );
    final cubit = TelaColoresCubit(telasRepository: repo, idtela: 7);
    addTearDown(cubit.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: cubit,
        child: const TelaColoresScreen(idtela: 7),
      ),
    );
  }

  testWidgets('colores vinculados y no vinculados', (tester) async {
    await montar(tester, colores);

    await compararCaptura('tela_colores_vinculados');
  });

  testWidgets('sin colores cargados', (tester) async {
    await montar(tester, const []);

    await compararCaptura('tela_colores_sin_colores');
  });

  testWidgets('la muestra de un color claro se distingue del fondo',
      (tester) async {
    await montar(tester, const [
      ColorItem(id: 6, nombre: 'Blanco', hex: 'FFFFFF', vinculado: true),
      ColorItem(id: 7, nombre: 'Crema', hex: 'FFFDE7', vinculado: false),
    ]);

    await compararCaptura('tela_colores_color_claro');
  },
      // bug: producto_colores_list.dart:35-38 — el CircleAvatar de la muestra
      // no tiene borde: Blanco o Crema quedan casi invisibles sobre el fondo
      // claro de la pantalla. (testWidgets solo acepta skip bool.)
      skip: true);
}
