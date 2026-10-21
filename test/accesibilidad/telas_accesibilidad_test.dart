import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/presentation/screens/screens.dart';

import '../helpers/fake_repositories.dart';
import 'accesibilidad_helpers.dart';

void main() {
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
  ];
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo', hex: 'C62828', vinculado: true),
    ColorItem(id: 2, nombre: 'Azul marino', hex: '1A237E', vinculado: true),
    ColorItem(id: 3, nombre: 'Verde', hex: '2E7D32', vinculado: false),
    ColorItem(id: 4, nombre: 'Blanco', hex: 'FFFFFF', vinculado: false),
  ];

  FakeTelasRepository repoConDatos() =>
      FakeTelasRepository(telas: telas, colores: colores);

  /// `/tela/:id` con sus dos blocs, como en app_router.
  Future<void> montarFormulario(WidgetTester tester, {required int id}) {
    final repo = repoConDatos();
    final telasBloc = TelasBloc(telasRepository: repo);
    final telaBloc = TelaBloc(telasRepository: repo, id: id);
    addTearDown(telasBloc.close);
    addTearDown(telaBloc.close);
    return montarPantalla(
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

  group('/telas (TelasScreen)', () {
    verificarGuias('lista con activas e inactivas', (tester) {
      final bloc = TelasBloc(telasRepository: repoConDatos());
      addTearDown(bloc.close);
      return montarPantalla(
        tester,
        BlocProvider.value(value: bloc, child: const TelasScreen()),
      );
    });
  });

  group('/tela/:idtela (TelaScreen)', () {
    verificarGuias('alta', (t) => montarFormulario(t, id: 0));
    verificarGuias('edición', (t) => montarFormulario(t, id: 1));
  });

  group('/tela-colores/:idtela (TelaColoresScreen)', () {
    verificarGuias('colores vinculados y no vinculados', (tester) {
      final cubit =
          TelaColoresCubit(telasRepository: repoConDatos(), idtela: 1);
      addTearDown(cubit.close);
      return montarPantalla(
        tester,
        BlocProvider.value(
          value: cubit,
          child: const TelaColoresScreen(idtela: 1),
        ),
      );
    });
  });
}
