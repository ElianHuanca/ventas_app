@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/colores/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/colores/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Repo cuya carga de colores no termina hasta completar [carga].
class _RepoLento extends FakeColoresRepository {
  final carga = Completer<List<ColorItem>>();

  @override
  Future<List<ColorItem>> getColores({bool soloActivos = true}) => carga.future;
}

// El listado solo recibe los colores activos (la baja es lógica y
// ColorItem no trae `activo`): no hay estado "inactivo" que capturar.
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

  Future<void> montar(
    WidgetTester tester,
    FakeColoresRepository repo, {
    bool asentar = true,
  }) async {
    final bloc = ColoresBloc(coloresRepository: repo);
    addTearDown(bloc.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(value: bloc, child: const ColoresScreen()),
      asentar: asentar,
    );
  }

  testWidgets('cada color con su muestra y su hex', (tester) async {
    await montar(tester, FakeColoresRepository(colores: colores));

    await compararCaptura('colores');
  });

  testWidgets('sin colores', (tester) async {
    await montar(tester, FakeColoresRepository());

    await compararCaptura('colores_vacia');
  });

  testWidgets('cargando', (tester) async {
    final lento = _RepoLento();
    await montar(tester, lento, asentar: false);
    // En el instante 0 el arco del indicador todavía no se ve: se avanza un
    // tiempo fijo de su animación (el reloj del test es determinístico).
    await tester.pump(const Duration(milliseconds: 400));

    // Se libera la carga aunque la captura falle: si no, el close() del
    // bloc espera ese handler y el test se cuelga hasta el timeout.
    try {
      await compararCaptura('colores_cargando');
    } finally {
      lento.carga.complete(colores);
    }
  });
}
