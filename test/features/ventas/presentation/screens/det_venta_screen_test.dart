import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeVentasRepository ventasRepo;
  late FakeTelasRepository telasRepo;
  late DetalleVentaFormCubit cubit;
  late TelasBloc telasBloc;

  final telas = [
    Tela(id: 1, nombre: 'Lino', precxcompra: 60),
    Tela(id: 2, nombre: 'Seda', precxcompra: 30),
  ];

  setUp(() {
    ventasRepo = FakeVentasRepository();
    telasRepo = FakeTelasRepository(telas: telas);
  });

  /// La pantalla con sus providers, como en app_router (sucursal 1).
  Widget pantalla() => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: telasBloc),
        ],
        child: const DetVenta(),
      );

  void crearBlocs(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    cubit = DetalleVentaFormCubit(
      ventasRepository: ventasRepo,
      idsucursal: 1,
    );
    telasBloc = TelasBloc(telasRepository: telasRepo, idsucursal: 1);
    addTearDown(cubit.close);
    addTearDown(telasBloc.close);
  }

  Future<void> montar(WidgetTester tester) async {
    crearBlocs(tester);
    await tester.pumpWidget(MaterialApp(home: pantalla()));
    await tester.pumpAndSettle();
  }

  Finder campo(String label) => find.widgetWithText(TextFormField, label);

  String textoDe(WidgetTester tester, String label) => tester
      .widget<EditableText>(find.descendant(
          of: campo(label), matching: find.byType(EditableText)))
      .controller
      .text;

  Finder enTabla(String texto) =>
      find.descendant(of: find.byType(DataTable), matching: find.text(texto));

  Future<void> elegirTela(WidgetTester tester, String nombre) async {
    await tester.tap(find.byType(DropdownMenu<Tela>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(nombre).last);
    await tester.pumpAndSettle();
  }

  Future<void> anadirLinea(
    WidgetTester tester, {
    required String tela,
    required String precio,
    required String cantidad,
  }) async {
    await elegirTela(tester, tela);
    await tester.enterText(campo('Precio'), precio);
    await tester.enterText(campo('Cantidad'), cantidad);
    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el formulario con la fecha y las telas de la sucursal',
      (tester) async {
    await montar(tester);

    expect(find.text('Registro Ventas'), findsOneWidget);
    expect(find.text('Fecha'), findsOneWidget);
    final hoy = cubit.state.fecha;
    expect(
        find.text('${hoy.day.toString().padLeft(2, '0')}/'
            '${hoy.month.toString().padLeft(2, '0')}/${hoy.year}'),
        findsOneWidget);
    expect(find.text('Seleccione una Tela'), findsOneWidget);
    expect(campo('Precio'), findsOneWidget);
    expect(campo('Cantidad'), findsOneWidget);
    expect(campo('Descuento'), findsOneWidget);
    expect(find.text('Añadir'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(telasRepo.lastIdsucursal, 1);

    await tester.tap(find.byType(DropdownMenu<Tela>));
    await tester.pumpAndSettle();
    expect(find.text('Lino'), findsWidgets);
    expect(find.text('Seda'), findsWidgets);
  });

  testWidgets('Añadir agrega la línea con su total y limpia precio y cantidad',
      (tester) async {
    await montar(tester);

    await anadirLinea(tester, tela: 'Lino', precio: '100', cantidad: '2');

    expect(enTabla('Lino'), findsOneWidget);
    expect(enTabla('2.0mts'), findsOneWidget);
    expect(enTabla('100.0Bs'), findsOneWidget);
    expect(enTabla('200.0Bs'), findsOneWidget);
    expect(enTabla('200.0 Bs'), findsOneWidget);
    expect(textoDe(tester, 'Precio'), '');
    expect(textoDe(tester, 'Cantidad'), '');
  });

  testWidgets('quitar una línea la saca de la tabla y descuenta el total',
      (tester) async {
    await montar(tester);
    await anadirLinea(tester, tela: 'Lino', precio: '100', cantidad: '2');
    await anadirLinea(tester, tela: 'Seda', precio: '45', cantidad: '3');
    expect(enTabla('335.0 Bs'), findsOneWidget);

    // La última línea agregada queda primera: Lino es la segunda fila
    await tester.tap(find.byIcon(Icons.delete_forever_rounded).at(1));
    await tester.pumpAndSettle();

    expect(enTabla('Lino'), findsNothing);
    expect(enTabla('Seda'), findsOneWidget);
    expect(enTabla('135.0 Bs'), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever_rounded), findsOneWidget);
  });

  testWidgets(
      'Guardar crea la venta con líneas, descuento y fecha y avisa el éxito',
      (tester) async {
    await montar(tester);
    cubit.onFechaChanged(DateTime(2024, 6, 10));
    await anadirLinea(tester, tela: 'Lino', precio: '100', cantidad: '2');
    await tester.enterText(campo('Descuento'), '15');

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Realizado correctamente'), findsOneWidget);
    // Una sola llamada (registrar_venta_telas) con todo el carrito
    final envio = ventasRepo.ventasRegistradas.single;
    expect(envio['idsucursal'], 1);
    expect(envio['fecha'], DateTime(2024, 6, 10));
    expect(envio['descuento'], 15.0);
    expect(envio['detalles'], [
      {
        'idtelas': 1,
        'nombre': 'Lino',
        'cantidad': 2.0,
        'precio': 100.0,
        'total': 200.0,
        // (100 - 60 de compra) * 2
        'ganancias': 80.0,
      },
    ]);
    expect(envio['idOperacion'], isNotNull);
  });

  testWidgets('Guardar sin líneas avisa "Hubo un error" y no llama repos',
      (tester) async {
    await montar(tester);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Hubo un error'), findsOneWidget);
    expect(ventasRepo.ventasRegistradas, isEmpty);
  });

  testWidgets('Guardar con descuento inválido avisa "Hubo un error"',
      (tester) async {
    await montar(tester);
    await anadirLinea(tester, tela: 'Lino', precio: '100', cantidad: '2');
    await tester.enterText(campo('Descuento'), 'abc');

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Hubo un error'), findsOneWidget);
    expect(ventasRepo.ventasRegistradas, isEmpty);
  });

  testWidgets('al guardar con éxito vuelve a la pantalla anterior',
      (tester) async {
    crearBlocs(tester);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('STUB VENTAS')),
        ),
        GoRoute(path: '/det_venta/:idsucursal', builder: (_, __) => pantalla()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    unawaited(router.push('/det_venta/1'));
    await tester.pumpAndSettle();
    await anadirLinea(tester, tela: 'Lino', precio: '100', cantidad: '2');

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('STUB VENTAS'), findsOneWidget);
    expect(find.text('Registro Ventas'), findsNothing);
    expect(find.text('Realizado correctamente'), findsOneWidget);
  });

  testWidgets('la fecha del formulario se muestra como dd/mm/aaaa',
      (tester) async {
    await montar(tester);

    cubit.onFechaChanged(DateTime(2024, 3, 5));
    await tester.pumpAndSettle();

    expect(find.text('05/03/2024'), findsOneWidget);
  });

  testWidgets('tocar Fecha abre el calendario y la fecha elegida queda',
      (tester) async {
    await montar(tester);
    cubit.onFechaChanged(DateTime(2024, 3, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('05/03/2024'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('20/03/2024'), findsOneWidget);
    expect(cubit.state.fecha, DateTime(2024, 3, 20));
  });

  testWidgets('cancelar el calendario conserva la fecha', (tester) async {
    await montar(tester);
    cubit.onFechaChanged(DateTime(2024, 3, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('05/03/2024'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('05/03/2024'), findsOneWidget);
    expect(cubit.state.fecha, DateTime(2024, 3, 5));
  });

  // En escritorio (la app corre en Windows) el DropdownMenu deja escribir; en
  // Android/iOS el campo es de solo lectura y este camino no se alcanza.
  testWidgets(
      'en escritorio, escribir una tela que no existe y confirmar no rompe '
      'la pantalla', (tester) async {
    await montar(tester);

    await tester.tap(find.byType(DropdownMenu<Tela>));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(DropdownMenu<Tela>),
            matching: find.byType(TextField)),
        'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(cubit.state.idtelas, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('al salir de la pantalla libera los campos de precio y cantidad',
      (tester) async {
    await montar(tester);
    final controllers = [
      for (final label in ['Precio', 'Cantidad'])
        tester.widget<TextFormField>(campo(label)).controller!,
    ];

    await tester.pumpWidget(const SizedBox());

    for (final c in controllers) {
      expect(() => ChangeNotifier.debugAssertNotDisposed(c), throwsFlutterError,
          reason: 'controller sin dispose()');
    }
  });
}
