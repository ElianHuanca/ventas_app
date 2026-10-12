import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/auth.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/shared/widgets/menu_index_cubit.dart';

import '../helpers/fake_repositories.dart';
import 'accesibilidad_helpers.dart';

void main() {
  /// Pantalla raíz como "Venta telas" (Screen1 sin back lleva el menú
  /// lateral como drawer) con el menú abierto encima.
  Future<void> abrirMenu(WidgetTester tester) async {
    final auth = FakeAuthRepository();
    await auth.iniciarSesion(
      email: FakeAuthRepository.emailOk,
      password: FakeAuthRepository.passwordOk,
    );
    final menuCubit = MenuIndexCubit();
    addTearDown(menuCubit.close);
    await montarPantalla(
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

  group('menú lateral (SideMenu)', () {
    verificarGuias('abierto con las secciones y la cuenta al pie', abrirMenu);
  });
}
