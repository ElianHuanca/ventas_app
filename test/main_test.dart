import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/config/config.dart';
import 'package:textiles_app/features/auth/auth.dart';
import 'package:textiles_app/features/shared/widgets/menu_index_cubit.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/main.dart';

import 'helpers/fake_repositories.dart';

/// `MyApp` (MaterialApp.router + tema + idiomas + cinta LOCAL) con los mismos
/// providers que arma `HuantexApp`, pero con fakes: `HuantexApp` crea el
/// `AuthRepositoryImpl` de Supabase y se prueba en `integration_test/`.
void main() {
  late FakeAuthRepository auth;

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    auth = FakeAuthRepository();
    final sucursales = SucursalesBloc(
      sucursalesRepository: FakeSucursalesRepository(
          sucursales: [Sucursal(id: 1, nombre: 'Centro')]),
    );
    addTearDown(sucursales.close);
    final menu = MenuIndexCubit();
    addTearDown(menu.close);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: auth),
        BlocProvider.value(value: menu),
        BlocProvider.value(value: sucursales),
      ],
      child: const MyApp(),
    ));
    await tester.pumpAndSettle();
  }

  BuildContext contexto(WidgetTester tester) =>
      tester.element(find.byType(LoginScreen));

  testWidgets('sin sesión abre en el login', (tester) async {
    await montar(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
      'la cinta LOCAL aparece solo contra una base que no es producción',
      (tester) async {
    await montar(tester);

    final cinta =
        find.byWidgetPredicate((w) => w is Banner && w.message == 'LOCAL');
    // Sin --dart-define los tests apuntan a la URL de producción
    expect(cinta, SupabaseConfig.isLocal ? findsOneWidget : findsNothing);
    expect(find.byWidgetPredicate((w) => w is Banner && w.message == 'DEBUG'),
        findsNothing,
        reason: 'debugShowCheckedModeBanner: false');
  });

  testWidgets('usa el tema de la app (Material 3, fondo propio)',
      (tester) async {
    await montar(tester);

    final tema = Theme.of(contexto(tester));
    expect(tema.useMaterial3, isTrue);
    expect(tema.scaffoldBackgroundColor, scaffoldBackgroundColor);
    expect(tema.appBarTheme.backgroundColor, scaffoldBackgroundColor);
  });

  testWidgets(
      'en un dispositivo en español los textos de Material están en '
      'español (lo necesitan los selectores de fecha)', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('es', 'BO')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await montar(tester);

    final ctx = contexto(tester);
    expect(Localizations.localeOf(ctx).languageCode, 'es');
    expect(MaterialLocalizations.of(ctx).cancelButtonLabel, 'Cancelar');
  });

  testWidgets('un idioma no soportado cae en uno soportado sin romper',
      (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await montar(tester);

    expect(tester.takeException(), isNull);
    expect(['es', 'en'],
        contains(Localizations.localeOf(contexto(tester)).languageCode));
  });

  testWidgets('al iniciar sesión pasa a la venta de telas (inicio)',
      (tester) async {
    await montar(tester);

    await tester.enterText(
        find.byKey(const Key('login_email')), FakeAuthRepository.emailOk);
    await tester.enterText(
        find.byKey(const Key('login_password')), FakeAuthRepository.passwordOk);
    await tester.pump();
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();

    expect(auth.haySesion, isTrue);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('CENTRO'), findsOneWidget);
  });
}
