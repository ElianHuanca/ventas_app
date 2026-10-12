@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

void main() {
  late FakeSucursalesRepository repo;

  setUp(() {
    repo = FakeSucursalesRepository(sucursales: [
      Sucursal(id: 1, nombre: 'Central'),
      Sucursal(id: 2, nombre: 'Norte'),
    ]);
  });

  /// Monta `/sucursal/:id` como en app_router.dart: SucursalesBloc global +
  /// SucursalBloc de la ruta.
  Future<void> montar(WidgetTester tester, {required int id}) async {
    final sucursalesBloc = SucursalesBloc(sucursalesRepository: repo);
    addTearDown(sucursalesBloc.close);
    await montarParaCaptura(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sucursalesBloc),
          BlocProvider(
            create: (_) => SucursalBloc(sucursalesRepository: repo, id: id),
          ),
        ],
        child: SucursalScreen(id: id),
      ),
    );
  }

  /// Escribe en el campo Nombre y cierra el teclado (tocar fuera del campo).
  Future<void> escribirNombre(WidgetTester tester, String texto) async {
    await tester.enterText(find.byType(TextFormField), texto);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  group('alta (id 0)', () {
    testWidgets('formulario vacío', (tester) async {
      await montar(tester, id: 0);

      await compararCaptura('sucursal_alta');
    });

    testWidgets('Guardar con el nombre vacío avisa el error', (tester) async {
      await montar(tester, id: 0);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Hubo un error'), findsOneWidget);

      await compararCaptura('sucursal_alta_nombre_vacio');
    });
  });

  group('edición', () {
    testWidgets('precarga la sucursal', (tester) async {
      await montar(tester, id: 2);

      await compararCaptura('sucursal_edicion');
    });

    testWidgets('Modificar con el nombre borrado avisa el error',
        (tester) async {
      await montar(tester, id: 2);

      await escribirNombre(tester, '');
      await tester.tap(find.text('Modificar'));
      await tester.pumpAndSettle();
      expect(find.text('Hubo un error'), findsOneWidget);

      await compararCaptura('sucursal_edicion_nombre_vacio');
    });
  });
}
