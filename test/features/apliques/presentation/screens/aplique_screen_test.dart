import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

/// Registra lo que llega a createAplique/updateAplique (el fake compartido
/// no lo guarda).
class _Repo extends FakeApliquesRepository {
  _Repo({super.apliques});

  final List<Map<String, dynamic>> creados = [];
  final List<Map<String, dynamic>> actualizados = [];
  final List<int> idsActualizados = [];

  @override
  Future<Aplique> createAplique(Map<String, dynamic> apliqueLike) async {
    final aplique = await super.createAplique(apliqueLike);
    creados.add(Map<String, dynamic>.from(apliqueLike));
    return aplique;
  }

  @override
  Future<Aplique> updateAplique(
      Map<String, dynamic> apliqueLike, int id) async {
    final aplique = await super.updateAplique(apliqueLike, id);
    actualizados.add(Map<String, dynamic>.from(apliqueLike));
    idsActualizados.add(id);
    return aplique;
  }
}

// La precarga de la edición ya está cubierta en
// test/features/shared/edicion_screens_test.dart.
void main() {
  late _Repo repo;
  late GoRouter router;

  setUp(() {
    repo = _Repo(apliques: [
      Aplique(
        id: 7,
        nombre: 'Estrella',
        costoFabricacion: 9,
        anchoCm: 4,
        altoCm: 3,
      ),
      Aplique(id: 8, nombre: 'Luna', costoFabricacion: 5, activo: false),
    ]);
  });

  /// Monta la lista (stub) y empuja /aplique/:id encima, como en la app.
  Future<void> montar(WidgetTester tester, int id) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final bloc = ApliquesBloc(apliquesRepository: repo);
    addTearDown(bloc.close);
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('STUB LISTA')),
        ),
        GoRoute(
          path: '/aplique/:idaplique',
          builder: (_, __) =>
              BlocProvider.value(value: bloc, child: ApliqueScreen(id: id)),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/aplique/$id');
    await tester.pumpAndSettle();
  }

  Finder campo(String label) => find.widgetWithText(TextFormField, label);

  Future<void> completar(
    WidgetTester tester, {
    String? nombre,
    String? ancho,
    String? alto,
    String? costo,
  }) async {
    if (nombre != null) await tester.enterText(campo('Nombre'), nombre);
    if (ancho != null) await tester.enterText(campo('Ancho (cm)'), ancho);
    if (alto != null) await tester.enterText(campo('Alto (cm)'), alto);
    if (costo != null) {
      await tester.enterText(campo('Costo de fabricación'), costo);
    }
    await tester.pump();
  }

  Future<void> tocar(WidgetTester tester, String boton) async {
    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();
  }

  SwitchListTile switchActivo(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile));

  group('crear', () {
    testWidgets(
        'muestra "Crear Aplique", el botón "Guardar" y sin switch Activo',
        (tester) async {
      await montar(tester, 0);

      expect(find.text('Crear Aplique'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.text('Modificar'), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(campo('Nombre'), findsOneWidget);
      expect(campo('Ancho (cm)'), findsOneWidget);
      expect(campo('Alto (cm)'), findsOneWidget);
      expect(campo('Costo de fabricación'), findsOneWidget);
    });

    testWidgets('"Guardar" envía nombre, medidas, costo y activo',
        (tester) async {
      await montar(tester, 0);

      await completar(tester,
          nombre: '  Corazón - Bolsa x50  ',
          ancho: '4.5',
          alto: '3',
          costo: '12.5');
      await tocar(tester, 'Guardar');

      expect(repo.creados, [
        {
          'id': 0,
          'nombre': 'Corazón - Bolsa x50',
          'ancho_cm': 4.5,
          'alto_cm': 3.0,
          'costo_fabricacion': 12.5,
          'activo': true,
        }
      ]);
      expect(repo.actualizados, isEmpty);
      // Avisa y vuelve a la lista
      expect(find.text('Realizado correctamente'), findsOneWidget);
      expect(find.text('STUB LISTA'), findsOneWidget);
    });

    testWidgets('las medidas son opcionales: vacías se envían como null',
        (tester) async {
      await montar(tester, 0);

      await completar(tester, nombre: 'Corazón', costo: '0');
      await tocar(tester, 'Guardar');

      final creado = repo.creados.single;
      expect(creado['ancho_cm'], isNull);
      expect(creado['alto_cm'], isNull);
      expect(creado['costo_fabricacion'], 0.0);
    });

    testWidgets('un error del repo avisa y se queda en el formulario',
        (tester) async {
      await montar(tester, 0);
      repo.error = Exception('sin conexión');

      await completar(tester, nombre: 'Corazón', costo: '10');
      await tocar(tester, 'Guardar');

      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('Crear Aplique'), findsOneWidget);
      expect(find.text('STUB LISTA'), findsNothing);
    });
  });

  group('validaciones (no llaman al repo)', () {
    Future<void> intentar(
      WidgetTester tester, {
      required String nombre,
      required String costo,
      String? ancho,
      String? alto,
    }) async {
      await montar(tester, 0);
      await completar(tester,
          nombre: nombre, costo: costo, ancho: ancho, alto: alto);
      await tocar(tester, 'Guardar');

      expect(repo.creados, isEmpty);
      expect(find.text('Hubo un error'), findsOneWidget);
      expect(find.text('Crear Aplique'), findsOneWidget);
    }

    testWidgets('nombre vacío', (tester) async {
      await intentar(tester, nombre: '   ', costo: '10');
    });

    testWidgets('costo no numérico', (tester) async {
      await intentar(tester, nombre: 'Corazón', costo: 'diez');
    });

    testWidgets('costo vacío', (tester) async {
      await intentar(tester, nombre: 'Corazón', costo: '');
    });

    testWidgets('costo negativo', (tester) async {
      await intentar(tester, nombre: 'Corazón', costo: '-1');
    });

    testWidgets('medida en 0', (tester) async {
      await intentar(tester, nombre: 'Corazón', costo: '10', ancho: '0');
    });

    testWidgets('medida no numérica', (tester) async {
      await intentar(tester, nombre: 'Corazón', costo: '10', alto: 'tres');
    });
  });

  group('switch Activo (edición)', () {
    testWidgets('aparece encendido para un aplique activo', (tester) async {
      await montar(tester, 7);

      expect(find.text('Activo'), findsOneWidget);
      expect(switchActivo(tester).value, true);
    });

    testWidgets('apagarlo y "Modificar" da de baja el aplique', (tester) async {
      await montar(tester, 7);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(switchActivo(tester).value, false);

      await tocar(tester, 'Modificar');

      expect(repo.idsActualizados, [7]);
      expect(repo.actualizados.single, {
        'id': 7,
        'nombre': 'Estrella',
        'ancho_cm': 4.0,
        'alto_cm': 3.0,
        'costo_fabricacion': 9.0,
        'activo': false,
      });
      expect(repo.creados, isEmpty);
      expect(find.text('STUB LISTA'), findsOneWidget);
    });

    testWidgets('un aplique inactivo precarga apagado y se puede reactivar',
        (tester) async {
      await montar(tester, 8);
      expect(switchActivo(tester).value, false);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tocar(tester, 'Modificar');

      expect(repo.idsActualizados, [8]);
      expect(repo.actualizados.single['activo'], true);
    });
  });
}
