import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:textiles_app/features/dashboard/presentation/screens/dashboard_screen.dart';

import '../../../../helpers/fake_repositories.dart';

/// No responde el top de telas hasta que se complete [respuesta].
class _DashboardLento extends FakeDashboardRepository {
  final respuesta = Completer<void>();

  _DashboardLento({super.topTelas, super.resumenTelas});

  @override
  Future<List<TopProducto>> getTopProductos(
      {required DateTime desde, required DateTime hasta}) async {
    await respuesta.future;
    return super.getTopProductos(desde: desde, hasta: hasta);
  }
}

/// Falla el resumen de telas (sin conexión) mientras [fallar] sea true.
class _DashboardSinConexion extends FakeDashboardRepository {
  bool fallar = true;

  _DashboardSinConexion({super.topTelas, super.resumenTelas});

  @override
  Future<ResumenVentas> getResumenVentas(
      {required DateTime desde, required DateTime hasta}) async {
    if (fallar) throw Exception('Sin conexión');
    return super.getResumenVentas(desde: desde, hasta: hasta);
  }
}

void main() {
  const topTelas = [
    TopProducto(nombre: 'Lino', totalVendido: 400, totalCantidad: 10),
    TopProducto(nombre: 'Seda', totalVendido: 200, totalCantidad: 20),
    TopProducto(nombre: 'Gasa', totalVendido: 100, totalCantidad: 5),
    TopProducto(nombre: 'Tul', totalVendido: 50, totalCantidad: 1),
  ];
  const resumen = ResumenVentas(total: 750, ganancias: 300, descuento: 10);

  late FakeDashboardRepository repo;
  late DashboardCubit cubit;

  setUp(() {
    repo = FakeDashboardRepository(topTelas: topTelas, resumenTelas: resumen);
  });

  /// Con las traducciones al español: el selector de período las exige
  /// (`locale: Locale('es')`), igual que `MyApp`.
  Future<void> montar(WidgetTester tester, {bool esperar = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    cubit = DashboardCubit(repository: repo, linea: LineaDashboard.telas);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('es'), Locale('en')],
      home: BlocProvider.value(value: cubit, child: const DashboardScreen()),
    ));
    if (esperar) await tester.pumpAndSettle();
  }

  String fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<String> nombresEnPantalla() => find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .where((t) => topTelas.any((p) => p.nombre == t))
      .cast<String>()
      .toList();

  List<double?> barras(WidgetTester tester) => tester
      .widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
      .map((b) => b.value)
      .toList();

  testWidgets('el período arranca en el mes actual hasta hoy', (tester) async {
    await montar(tester);
    final hoy = DateTime.now();

    expect(find.text('Período'), findsOneWidget);
    expect(
        find.text('${fmt(DateTime(hoy.year, hoy.month, 1))}  →  ${fmt(hoy)}'),
        findsOneWidget);
  });

  testWidgets('mientras carga muestra el progreso y no el resumen',
      (tester) async {
    final lento = _DashboardLento(topTelas: topTelas, resumenTelas: resumen);
    repo = lento;
    await montar(tester, esperar: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('750.00 Bs'), findsNothing);
    expect(find.text('Lino'), findsNothing);

    lento.respuesta.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('750.00 Bs'), findsOneWidget);
    expect(find.text('Lino'), findsOneWidget);
  });

  testWidgets('el resumen muestra total, ganancias y descuentos',
      (tester) async {
    await montar(tester);

    expect(find.text('750.00 Bs'), findsOneWidget);
    expect(find.text('300.00 Bs'), findsOneWidget);
    expect(find.text('10.00 Bs'), findsOneWidget);
  });

  testWidgets(
      'sin conexión avisa del error (no "Sin ventas") y reintentar '
      'recupera los datos', (tester) async {
    final sinConexion =
        _DashboardSinConexion(topTelas: topTelas, resumenTelas: resumen);
    repo = sinConexion;
    await montar(tester);

    expect(find.text('No se pudieron cargar las ventas. Revisá la conexión.'),
        findsOneWidget);
    expect(find.textContaining('Sin ventas'), findsNothing);
    expect(find.text('750.00 Bs'), findsNothing);

    sinConexion.fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudieron cargar'), findsNothing);
    expect(find.text('750.00 Bs'), findsOneWidget);
    expect(find.text('Lino'), findsOneWidget);
  });

  testWidgets('numera el ranking y las barras son proporcionales al primero',
      (tester) async {
    await montar(tester);

    expect(nombresEnPantalla(), ['Lino', 'Seda', 'Gasa', 'Tul']);
    for (final posicion in ['1', '2', '3', '4']) {
      expect(find.text(posicion), findsOneWidget);
    }
    expect(barras(tester), [1.0, 0.5, 0.25, 0.125]);
  });

  testWidgets('"Por monto" vuelve al orden por total después de "Por cantidad"',
      (tester) async {
    await montar(tester);

    await tester.tap(find.text('Por cantidad'));
    await tester.pumpAndSettle();
    expect(nombresEnPantalla(), ['Seda', 'Lino', 'Gasa', 'Tul']);
    expect(find.text('4 telas por cantidad vendida'), findsOneWidget);
    expect(barras(tester), [1.0, 0.5, 0.25, 0.05]);

    await tester.tap(find.text('Por monto'));
    await tester.pumpAndSettle();
    expect(nombresEnPantalla(), ['Lino', 'Seda', 'Gasa', 'Tul']);
    expect(find.text('4 telas por total vendido'), findsOneWidget);
    expect(find.text('400.00 Bs'), findsOneWidget);
  });

  testWidgets('tocar la vista ya elegida no cambia nada', (tester) async {
    await montar(tester);

    await tester.tap(find.text('Por monto'));
    await tester.pumpAndSettle();

    expect(cubit.state.verPorCantidad, isFalse);
    expect(nombresEnPantalla(), ['Lino', 'Seda', 'Gasa', 'Tul']);
  });

  testWidgets('con ventas en 0 las barras quedan vacías (sin dividir por 0)',
      (tester) async {
    repo.topTelas = const [
      TopProducto(nombre: 'Lino', totalVendido: 0, totalCantidad: 0),
      TopProducto(nombre: 'Seda', totalVendido: 0, totalCantidad: 0),
    ];
    await montar(tester);

    expect(barras(tester), [0.0, 0.0]);
    expect(tester.takeException(), isNull);
  });

  group('selector de período', () {
    Future<MaterialLocalizations> abrirEnModoTexto(WidgetTester tester) async {
      await tester.tap(find.text('Período'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      return MaterialLocalizations.of(
          tester.element(find.byType(TextField).first));
    }

    Finder camposDelSelector() => find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextField));

    testWidgets('elegir un rango vuelve a consultar las 2 RPC con esas fechas',
        (tester) async {
      await montar(tester);
      final hoy = DateTime.now();
      final desde = DateTime(hoy.year - 1, 1, 1);
      final hasta = DateTime(hoy.year - 1, 1, 31);
      repo.rangos.clear();

      final textos = await abrirEnModoTexto(tester);
      await tester.enterText(
          camposDelSelector().first, textos.formatCompactDate(desde));
      await tester.enterText(
          camposDelSelector().last, textos.formatCompactDate(hasta));
      await tester.pumpAndSettle();
      await tester.tap(find.text(textos.okButtonLabel));
      await tester.pumpAndSettle();

      expect(find.text('${fmt(desde)}  →  ${fmt(hasta)}'), findsOneWidget);
      expect(repo.rangos, hasLength(2));
      expect(repo.rangos.every((r) => r[0] == desde && r[1] == hasta), isTrue);
    });

    testWidgets('está en español aunque el dispositivo no lo esté',
        (tester) async {
      await montar(tester);

      final textos = await abrirEnModoTexto(tester);

      expect(textos.cancelButtonLabel, 'Cancelar');
    });

    testWidgets('cancelar conserva el período y no vuelve a consultar',
        (tester) async {
      await montar(tester);
      final antes = (cubit.state.desde, cubit.state.hasta);
      repo.rangos.clear();

      final textos = await abrirEnModoTexto(tester);
      await tester.tap(find.text(textos.cancelButtonLabel));
      await tester.pumpAndSettle();

      expect((cubit.state.desde, cubit.state.hasta), antes);
      expect(repo.rangos, isEmpty);
    });
  });
}
