@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/auth.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:textiles_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/shared/widgets/menu_index_cubit.dart';

import '../../helpers/fake_repositories.dart';
import 'chica_helpers.dart';

// `/dashboard`, `/login` y el menú lateral abierto.
void main() {
  testWidgets('dashboard: telas por total vendido', (tester) async {
    final cubit = DashboardCubit(
      repository: FakeDashboardRepository(
        topTelas: const [
          TopProducto(
              nombre: 'Lino', totalVendido: 14280.5, totalCantidad: 714.5),
          TopProducto(nombre: 'Seda', totalVendido: 3150, totalCantidad: 90),
          TopProducto(
              nombre: 'Gabardina', totalVendido: 2875, totalCantidad: 230),
          TopProducto(nombre: 'Tul', totalVendido: 1240, totalCantidad: 310),
          TopProducto(
              nombre: 'Popelina', totalVendido: 615.75, totalCantidad: 82.5),
        ],
        resumenTelas: const ResumenVentas(
            total: 22161.25, ganancias: 6920.4, descuento: 85),
      ),
    );
    addTearDown(cubit.close);
    // Período fijo: el default (primer día del mes → hoy) usa DateTime.now()
    await cubit.cambiarRango(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
    await montarChica(
      tester,
      BlocProvider.value(value: cubit, child: const DashboardScreen()),
    );

    await compararChica('dashboard');
  });

  testWidgets('login con los datos completos', (tester) async {
    await montarChica(
      tester,
      BlocProvider(
        create: (_) => LoginFormCubit(authRepository: FakeAuthRepository()),
        child: const LoginScreen(),
      ),
    );
    await tester.enterText(
        find.byKey(const Key('login_email')), FakeAuthRepository.emailOk);
    await tester.enterText(
        find.byKey(const Key('login_password')), FakeAuthRepository.passwordOk);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await compararChica('login');
  });

  testWidgets('menú lateral abierto con la cuenta al pie', (tester) async {
    final auth = FakeAuthRepository();
    await auth.iniciarSesion(
      email: FakeAuthRepository.emailOk,
      password: FakeAuthRepository.passwordOk,
    );
    final menuCubit = MenuIndexCubit();
    addTearDown(menuCubit.close);
    await montarChica(
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

    await compararChica('side_menu');
  });
}
