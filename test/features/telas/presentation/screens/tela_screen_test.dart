import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

/// Registra lo que llega a createTela/updateTela (el fake compartido no lo
/// guarda) y permite que getTela falle.
class _Repo extends FakeTelasRepository {
  _Repo({super.telas});

  final List<Map<String, dynamic>> creadas = [];
  final List<Map<String, dynamic>> actualizadas = [];
  final List<int> idsActualizados = [];
  Object? getTelaError;

  @override
  Future<Tela> getTela(int id) async {
    if (getTelaError != null) throw getTelaError!;
    return super.getTela(id);
  }

  @override
  Future<Tela> createTela(Map<String, dynamic> telaLike) async {
    final tela = await super.createTela(telaLike);
    creadas.add(Map<String, dynamic>.from(telaLike));
    return tela;
  }

  @override
  Future<Tela> updateTela(Map<String, dynamic> telaLike, int id) async {
    final tela = await super.updateTela(telaLike, id);
    actualizadas.add(Map<String, dynamic>.from(telaLike));
    idsActualizados.add(id);
    return tela;
  }
}

void main() {
  late _Repo repo;
  late GoRouter router;

  final lino = Tela(
    id: 3,
    nombre: 'Lino',
    precxmen: 10,
    precxmay: 8,
    precxrollo: 300,
    precxcompra: 6,
  );

  setUp(() {
    repo = _Repo(telas: [lino]);
  });

  /// Monta la lista (stub) y empuja /tela/:id encima, como en la app.
  Future<void> montar(WidgetTester tester, int id) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final telasBloc = TelasBloc(telasRepository: repo);
    final telaBloc = TelaBloc(telasRepository: repo, id: id);
    addTearDown(telasBloc.close);
    addTearDown(telaBloc.close);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('STUB LISTA')),
        ),
        GoRoute(
          path: '/tela/:idtela',
          builder: (_, __) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: telasBloc),
              BlocProvider.value(value: telaBloc),
            ],
            child: TelaScreen(id: id),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/tela/$id');
    await tester.pumpAndSettle();
  }

  Finder campo(String label) => find.widgetWithText(TextFormField, label);

  Future<void> completar(
    WidgetTester tester, {
    String? nombre,
    String? men,
    String? may,
    String? rollo,
    String? compra,
  }) async {
    if (nombre != null) await tester.enterText(campo('Nombre'), nombre);
    if (men != null) await tester.enterText(campo('Precio X Menor'), men);
    if (may != null) await tester.enterText(campo('Precio X Mayor'), may);
    if (rollo != null) await tester.enterText(campo('Precio X Rollo'), rollo);
    if (compra != null) await tester.enterText(campo('Precio Compra'), compra);
    await tester.pump();
  }

  Future<void> tocar(WidgetTester tester, String boton) async {
    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();
  }

  group('crear', () {
    testWidgets('muestra "Crear Tela", el botón "Guardar" y sin switch Activo',
        (tester) async {
      await montar(tester, 0);

      expect(find.text('Crear Tela'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.text('Modificar'), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(campo('Nombre'), findsOneWidget);
      expect(campo('Precio X Menor'), findsOneWidget);
      expect(campo('Precio X Mayor'), findsOneWidget);
      expect(campo('Precio X Rollo'), findsOneWidget);
      expect(campo('Precio Compra'), findsOneWidget);
    });

    testWidgets('"Guardar" envía al repo el nombre y los precios parseados',
        (tester) async {
      await montar(tester, 0);

      await completar(tester,
          nombre: '  Gabardina  ',
          men: '10.5',
          may: '9',
          rollo: '300',
          compra: '7.25');
      await tocar(tester, 'Guardar');

      expect(repo.creadas, [
        {
          'id': 0,
          'nombre': 'Gabardina',
          'precxmen': 10.5,
          'precxmay': 9.0,
          'precxrollo': 300.0,
          'precxcompra': 7.25,
          'activo': true,
        }
      ]);
      expect(repo.actualizadas, isEmpty);
      // Avisa y vuelve a la lista
      expect(find.text('Realizado correctamente'), findsOneWidget);
      expect(find.text('STUB LISTA'), findsOneWidget);
    });

    testWidgets('un error del repo avisa y se queda en el formulario',
        (tester) async {
      await montar(tester, 0);
      repo.error = Exception('sin conexión');

      await completar(tester,
          nombre: 'Gabardina', men: '10', may: '9', rollo: '300', compra: '7');
      await tocar(tester, 'Guardar');

      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('Crear Tela'), findsOneWidget);
      expect(find.text('STUB LISTA'), findsNothing);
    });
  });

  group('validaciones (no llaman al repo)', () {
    testWidgets('nombre vacío', (tester) async {
      await montar(tester, 0);

      await completar(tester,
          nombre: '   ', men: '10', may: '9', rollo: '300', compra: '7');
      await tocar(tester, 'Guardar');

      expect(repo.creadas, isEmpty);
      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('Crear Tela'), findsOneWidget);
    });

    testWidgets('precio no numérico', (tester) async {
      await montar(tester, 0);

      await completar(tester,
          nombre: 'Gabardina',
          men: 'diez',
          may: '9',
          rollo: '300',
          compra: '7');
      await tocar(tester, 'Guardar');

      expect(repo.creadas, isEmpty);
      expect(find.text('Hubo un error'), findsOneWidget);
    });

    testWidgets('precio vacío', (tester) async {
      await montar(tester, 0);

      await completar(tester,
          nombre: 'Gabardina', men: '10', may: '9', compra: '7');
      await tocar(tester, 'Guardar');

      expect(repo.creadas, isEmpty);
      expect(find.text('Hubo un error'), findsOneWidget);
    });

    testWidgets('precio negativo', (tester) async {
      await montar(tester, 0);

      await completar(tester,
          nombre: 'Gabardina', men: '10', may: '9', rollo: '300', compra: '-1');
      await tocar(tester, 'Guardar');

      expect(repo.creadas, isEmpty);
      expect(find.text('Hubo un error'), findsOneWidget);
    });
  });

  group('editar', () {
    testWidgets('precarga los campos con "Editar Tela" y "Modificar"',
        (tester) async {
      await montar(tester, 3);

      expect(find.text('Editar Tela'), findsOneWidget);
      expect(find.text('Modificar'), findsOneWidget);
      expect(find.text('Guardar'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Lino'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '10.0'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '8.0'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '300.0'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '6.0'), findsOneWidget);
      // Switch Activo visible y encendido
      expect(find.text('Activo'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          true);
    });

    testWidgets('"Modificar" envía el id y los cambios al repo',
        (tester) async {
      await montar(tester, 3);

      await completar(tester, nombre: 'Lino Fino', men: '11.5');
      await tocar(tester, 'Modificar');

      expect(repo.idsActualizados, [3]);
      expect(repo.actualizadas.single, {
        'id': 3,
        'nombre': 'Lino Fino',
        'precxmen': 11.5,
        'precxmay': 8.0,
        'precxrollo': 300.0,
        'precxcompra': 6.0,
        'activo': true,
      });
      expect(repo.creadas, isEmpty);
      expect(find.text('Realizado correctamente'), findsOneWidget);
      expect(find.text('STUB LISTA'), findsOneWidget);
    });

    testWidgets('apagar el switch Activo da de baja la tela al modificar',
        (tester) async {
      await montar(tester, 3);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          false);

      await tocar(tester, 'Modificar');

      expect(repo.actualizadas.single['activo'], false);
      expect(repo.idsActualizados, [3]);
    });

    testWidgets('una tela inactiva precarga el switch apagado y se reactiva',
        (tester) async {
      repo.telas = [
        Tela(
          id: 4,
          nombre: 'Seda',
          precxmen: 25,
          precxmay: 20,
          precxrollo: 700,
          precxcompra: 15,
          activo: false,
        ),
      ];
      await montar(tester, 4);

      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          false);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tocar(tester, 'Modificar');

      expect(repo.actualizadas.single['activo'], true);
    });

    testWidgets(
        'una tela con un precio en 0 (no se vende así) se guarda sin '
        'tener que reescribirlo', (tester) async {
      repo.telas = [
        Tela(
          id: 5,
          nombre: 'Tul',
          precxmen: 5,
          precxmay: 4,
          precxrollo: 0,
          precxcompra: 3,
        ),
      ];
      await montar(tester, 5);

      await completar(tester, nombre: 'Tul Ilusión');
      await tocar(tester, 'Modificar');

      expect(repo.actualizadas.single['nombre'], 'Tul Ilusión');
      expect(repo.actualizadas.single['precxrollo'], 0);
    });
  });

  testWidgets('si la carga de la tela falla, la pantalla no revienta',
      (tester) async {
    repo.getTelaError = Exception('sin conexión');
    await montar(tester, 3);

    expect(tester.takeException(), isNull);
  });
}
