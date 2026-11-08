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
import '../golden_helpers.dart';

/// `/dashboard/telas`, `/dashboard/apliques`, `/login` y el menú lateral
/// abierto.
void capturasDeDashboardLoginMenu(
  Dispositivo d, {
  bool todosLosEstados = false,
  Set<String> omitidas = const {},
}) {
  /// El dashboard de [linea] con un período fijo (el default, primer día del
  /// mes → hoy, usa DateTime.now()).
  Future<void> montarDashboard(WidgetTester tester,
      FakeDashboardRepository repo, LineaDashboard linea) async {
    final cubit = DashboardCubit(repository: repo, linea: linea);
    addTearDown(cubit.close);
    await cubit.cambiarRango(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
    await d.montar(
      tester,
      BlocProvider.value(value: cubit, child: const DashboardScreen()),
    );
  }

  testWidgets('dashboard: telas por total vendido',
      skip: omitidas.contains('dashboard'), (tester) async {
    await montarDashboard(
      tester,
      FakeDashboardRepository(
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
      LineaDashboard.telas,
    );

    await d.comparar('dashboard');
  });

  testWidgets('dashboard: apliques por total vendido',
      skip: omitidas.contains('dashboard_apliques'), (tester) async {
    await montarDashboard(
      tester,
      FakeDashboardRepository(
        topApliques: const [
          TopProducto(
              nombre: 'Flor bordada 10x10',
              totalVendido: 11250,
              totalCantidad: 450),
          TopProducto(
              nombre: 'Corazón 5x5', totalVendido: 640, totalCantidad: 80),
          TopProducto(
              nombre: 'Mariposa 8x6', totalVendido: 555, totalCantidad: 30),
        ],
        resumenApliques: const ResumenVentas(
            total: 12445, ganancias: 5180.5, descuento: 20),
      ),
      LineaDashboard.apliques,
    );

    await d.comparar('dashboard_apliques');
  });

  if (todosLosEstados) {
    testWidgets('dashboard: período sin ventas',
        skip: omitidas.contains('dashboard_sin_ventas'), (tester) async {
      await montarDashboard(
          tester, FakeDashboardRepository(), LineaDashboard.telas);

      await d.comparar('dashboard_sin_ventas');
    });
  }

  /// Login con las credenciales escritas y el foco afuera.
  Future<void> montarLogin(WidgetTester tester, String clave) async {
    await d.montar(
      tester,
      BlocProvider(
        create: (_) => LoginFormCubit(authRepository: FakeAuthRepository()),
        child: const LoginScreen(),
      ),
    );
    await tester.enterText(
        find.byKey(const Key('login_email')), FakeAuthRepository.emailOk);
    await tester.enterText(find.byKey(const Key('login_password')), clave);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  testWidgets('login con los datos completos', skip: omitidas.contains('login'),
      (tester) async {
    await montarLogin(tester, FakeAuthRepository.passwordOk);

    await d.comparar('login');
  });

  if (todosLosEstados) {
    testWidgets('login con credenciales incorrectas',
        skip: omitidas.contains('login_error'), (tester) async {
      await montarLogin(tester, 'incorrecta');
      await tester.ensureVisible(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('login_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Email o contraseña incorrectos'), findsOneWidget);
      await d.comparar('login_error');
    });
  }

  testWidgets('menú lateral abierto con la cuenta al pie',
      skip: omitidas.contains('side_menu'), (tester) async {
    final auth = FakeAuthRepository();
    await auth.iniciarSesion(
      email: FakeAuthRepository.emailOk,
      password: FakeAuthRepository.passwordOk,
    );
    final menuCubit = MenuIndexCubit();
    addTearDown(menuCubit.close);
    await d.montar(
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

    await d.comparar('side_menu');
  });
}
