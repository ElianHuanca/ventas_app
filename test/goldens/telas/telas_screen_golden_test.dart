@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Deja la carga del listado en espera hasta completar [carga] (para que
/// se vea el loader).
class _RepoConCargaPendiente extends FakeTelasRepository {
  _RepoConCargaPendiente({super.telas});

  final carga = Completer<void>();

  @override
  Future<List<Tela>> getTelas({bool soloActivos = true}) async {
    await carga.future;
    return super.getTelas(soloActivos: soloActivos);
  }
}

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
    Tela(
      id: 4,
      nombre: 'Lino Rústico',
      precxmen: 32,
      precxmay: 27,
      precxrollo: 1300,
      precxcompra: 20,
    ),
  ];

  Future<void> montar(
    WidgetTester tester,
    FakeTelasRepository repo, {
    bool asentar = true,
  }) async {
    final bloc = TelasBloc(telasRepository: repo);
    addTearDown(bloc.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(value: bloc, child: const TelasScreen()),
      asentar: asentar,
    );
  }

  /// Escribe en el buscador y lo desenfoca (sin cursor en la captura).
  Future<void> buscar(WidgetTester tester, String texto) async {
    await tester.enterText(find.byType(TextField), texto);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  testWidgets('lista con activas e inactivas y sus precios', (tester) async {
    await montar(tester, FakeTelasRepository(telas: telas));

    await compararCaptura('telas_lista');
  });

  testWidgets('búsqueda con resultados', (tester) async {
    await montar(tester, FakeTelasRepository(telas: telas));
    await buscar(tester, 'lino');

    await compararCaptura('telas_busqueda');
  });

  testWidgets('búsqueda sin resultados', (tester) async {
    await montar(tester, FakeTelasRepository(telas: telas));
    await buscar(tester, 'algodón');

    await compararCaptura('telas_busqueda_sin_resultados');
  });

  testWidgets('sin telas registradas', (tester) async {
    await montar(tester, FakeTelasRepository());

    await compararCaptura('telas_vacia');
  });

  testWidgets('cargando', (tester) async {
    // El loader no pinta fondo (bug en full_screen_loader_golden_test.dart)
    final repo = _RepoConCargaPendiente(telas: telas);
    await montar(tester, repo, asentar: false);
    // En el primer frame el spinner es un punto: se avanza a un instante fijo
    await tester.pump(const Duration(milliseconds: 400));

    // Se libera la carga aunque la captura falle: si no, el close() del
    // bloc espera ese handler y el test se cuelga hasta el timeout.
    try {
      await compararCaptura('telas_cargando');
    } finally {
      repo.carga.complete();
    }
    await tester.pumpAndSettle();
  });
}
