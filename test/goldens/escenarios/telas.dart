import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// `/telas`, `/tela/:id` y `/tela-colores/:id`.
void capturasDeTelas(
  Dispositivo d, {
  bool todosLosEstados = false,
  Set<String> omitidas = const {},
}) {
  final telas = [
    Tela(
      id: 1,
      nombre: 'Lino',
      precxmen: 35,
      precxmay: 30,
      precxrollo: 1500,
      precxcompra: 22,
    ),
    Tela(
      id: 2,
      nombre: 'Seda',
      precxmen: 60,
      precxmay: 52,
      precxrollo: 2800,
      precxcompra: 40,
      activo: false,
    ),
    Tela(
      id: 3,
      nombre: 'Gabardina',
      precxmen: 28,
      precxmay: 24.5,
      precxrollo: 1100,
      precxcompra: 18,
    ),
    Tela(
      id: 4,
      nombre: 'Lino Rústico',
      precxmen: 32,
      precxmay: 27,
      precxrollo: 1300,
      precxcompra: 20,
    ),
  ];

  /// `/tela/:id` (0 = alta) con sus dos blocs, como en app_router.
  Future<void> montarTela(WidgetTester tester, int id) async {
    final repo = FakeTelasRepository(telas: telas);
    final telasBloc = TelasBloc(telasRepository: repo);
    final telaBloc = TelaBloc(telasRepository: repo, id: id);
    addTearDown(telasBloc.close);
    addTearDown(telaBloc.close);
    await d.montar(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: telasBloc),
          BlocProvider.value(value: telaBloc),
        ],
        child: TelaScreen(id: id),
      ),
    );
  }

  testWidgets('listado de telas con sus precios',
      skip: omitidas.contains('telas'), (tester) async {
    final bloc = TelasBloc(telasRepository: FakeTelasRepository(telas: telas));
    addTearDown(bloc.close);
    await d.montar(
      tester,
      BlocProvider.value(value: bloc, child: const TelasScreen()),
    );

    await d.comparar('telas');
  });

  testWidgets('formulario de la tela (edición)',
      skip: omitidas.contains('tela_edicion'), (tester) async {
    await montarTela(tester, 1);

    await d.comparar('tela_edicion');
  });

  if (todosLosEstados) {
    testWidgets('formulario de la tela (alta)',
        skip: omitidas.contains('tela_alta'), (tester) async {
      await montarTela(tester, 0);

      await d.comparar('tela_alta');
    });
  }

  testWidgets('colores de la tela', skip: omitidas.contains('tela_colores'),
      (tester) async {
    final cubit = TelaColoresCubit(
      telasRepository: FakeTelasRepository(
        telas: [Tela(id: 7, nombre: 'Lino')],
        colores: const [
          ColorItem(id: 1, nombre: 'Rojo', hex: 'C62828', vinculado: true),
          ColorItem(
              id: 2, nombre: 'Azul marino', hex: '1A237E', vinculado: true),
          ColorItem(id: 3, nombre: 'Verde', hex: '2E7D32', vinculado: false),
          ColorItem(id: 4, nombre: 'Beige', hex: 'D7CCC8', vinculado: true),
          ColorItem(id: 5, nombre: 'Negro', hex: '000000', vinculado: false),
        ],
      ),
      idtela: 7,
    );
    addTearDown(cubit.close);
    await d.montar(
      tester,
      BlocProvider.value(
        value: cubit,
        child: const TelaColoresScreen(idtela: 7),
      ),
    );

    await d.comparar('tela_colores');
  });
}
