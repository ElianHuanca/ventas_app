@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/auth.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/shared/widgets/menu_index_cubit.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

void main() {
  late FakeAuthRepository auth;
  late MenuIndexCubit menuCubit;

  setUp(() async {
    auth = FakeAuthRepository();
    await auth.iniciarSesion(
      email: FakeAuthRepository.emailOk,
      password: FakeAuthRepository.passwordOk,
    );
    menuCubit = MenuIndexCubit();
  });
  tearDown(() => menuCubit.close());

  /// Pantalla raíz como la de "Venta telas" (Screen1 sin back: con menú)
  /// y el menú lateral abierto encima.
  Future<void> abrirMenu(WidgetTester tester) async {
    await montarParaCaptura(
      tester,
      RepositoryProvider<AuthRepository>.value(
        value: auth,
        child: BlocProvider.value(
          value: menuCubit,
          child: Screen1(
            backRoute: false,
            title: 'Sucursales',
            isGridview: true,
            widget: [
              ItemDashboard(
                  title: 'Central', iconData: Icons.store, onTap: () {}),
              ItemDashboard(
                  title: 'Norte', iconData: Icons.store, onTap: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
  }

  testWidgets('abierto en "Venta telas" con la cuenta al pie', (tester) async {
    await abrirMenu(tester);

    expect(find.byType(NavigationDrawer), findsOneWidget);
    expect(find.text(FakeAuthRepository.emailOk), findsOneWidget);
    await compararCaptura('side_menu_abierto');
  });

  testWidgets('marca la sección guardada en el MenuIndexCubit', (tester) async {
    menuCubit.setIndex(6); // Colores
    await abrirMenu(tester);

    expect(
      tester
          .widget<NavigationDrawer>(find.byType(NavigationDrawer))
          .selectedIndex,
      6,
    );
    await compararCaptura('side_menu_colores_seleccionado');
  });
}
