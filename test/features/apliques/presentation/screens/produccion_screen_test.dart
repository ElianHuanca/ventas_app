import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeApliquesRepository repo;
  late ProduccionFormCubit cubit;

  final apliques = [
    Aplique(id: 1, nombre: 'Flor'),
    Aplique(id: 2, nombre: 'Luna'),
  ];
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo', hex: '#FF0000', vinculado: true),
    ColorItem(id: 2, nombre: 'Verde', vinculado: false),
    ColorItem(id: 3, nombre: 'Azul', hex: '#0000FF', vinculado: true),
  ];
  const stock = [
    StockAplique(
        apliqueId: 1,
        colorId: 1,
        colorNombre: 'Rojo',
        hex: '#FF0000',
        stock: 7),
  ];

  setUp(() {
    repo = FakeApliquesRepository(
      apliques: apliques,
      colores: colores,
      stock: stock,
    );
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    cubit = ProduccionFormCubit(apliquesRepository: repo, idsucursal: 1);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider.value(value: cubit, child: ProduccionScreen()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> seleccionarAplique(WidgetTester tester, String nombre) async {
    await tester.tap(find.byType(DropdownMenu<Aplique>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(nombre).last);
    await tester.pumpAndSettle();
  }

  Future<void> seleccionarColor(WidgetTester tester, String texto) async {
    await tester.tap(find.byType(DropdownMenu<ColorItem>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto).last);
    await tester.pumpAndSettle();
  }

  /// Texto visible actualmente en el dropdown de color.
  String textoDropdownColor(WidgetTester tester) {
    final field = tester.widget<TextField>(find.descendant(
      of: find.byType(DropdownMenu<ColorItem>),
      matching: find.byType(TextField),
    ));
    return field.controller!.text;
  }

  testWidgets('renderiza dropdowns, cantidad y botones Añadir/Guardar',
      (tester) async {
    await montar(tester);

    expect(find.text('Fabricación'), findsOneWidget);
    expect(find.text('Fecha'), findsOneWidget);
    expect(find.text('Seleccione un Aplique'), findsOneWidget);
    expect(find.text('Seleccione un Color'), findsOneWidget);
    expect(find.text('Cantidad fabricada'), findsOneWidget);
    expect(find.text('Añadir'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('flujo feliz: añade la línea a la tabla y Guardar envía el lote',
      (tester) async {
    await montar(tester);

    await seleccionarAplique(tester, 'Flor');
    await seleccionarColor(tester, 'Rojo (stock: 7.0)');
    await tester.enterText(find.byType(TextFormField), '3');
    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();

    // La línea aparece en la tabla
    expect(find.text('3.0 uds'), findsOneWidget);
    expect(cubit.state.detProducciones.single['cantidad'], 3.0);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // El fake recibió el lote completo con la fecha
    final creada = repo.produccionesCreadas.single;
    expect(creada['sucursalId'], 1);
    expect(creada['fecha'], isA<DateTime>());
    expect(creada['lineas'], [
      {'idaplique': 1, 'idcolor': 1, 'cantidad': 3.0},
    ]);

    // El listado se limpia y se muestra el snackbar de éxito
    expect(cubit.state.detProducciones, isEmpty);
    expect(find.text('3.0 uds'), findsNothing);
    expect(
        find.text('Producción registrada, stock actualizado'), findsOneWidget);
  });

  testWidgets('Añadir sin selección muestra error y no agrega línea',
      (tester) async {
    await montar(tester);

    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();

    expect(find.text('Seleccione un aplique'), findsOneWidget);
    expect(cubit.state.detProducciones, isEmpty);
    expect(find.text('3.0 uds'), findsNothing);
  });

  testWidgets('al cambiar de aplique el color se reinicia (idcolor 0 y hint)',
      (tester) async {
    await montar(tester);

    await seleccionarAplique(tester, 'Flor');
    await seleccionarColor(tester, 'Rojo (stock: 7.0)');
    expect(cubit.state.idcolor, 1);
    expect(textoDropdownColor(tester), 'Rojo (stock: 7.0)');

    await seleccionarAplique(tester, 'Luna');

    expect(cubit.state.idapliques, 2);
    expect(cubit.state.idcolor, 0);
    // La key reinicia la selección visible: queda vacío (muestra el hint)
    expect(textoDropdownColor(tester), '');
    expect(find.text('Seleccione un Color'), findsOneWidget);
  });

  testWidgets('al elegir el color muestra el stock actual de la sucursal',
      (tester) async {
    await montar(tester);
    expect(find.textContaining('Stock actual'), findsNothing);

    await seleccionarAplique(tester, 'Flor');
    await seleccionarColor(tester, 'Rojo (stock: 7.0)');

    expect(find.text('Stock actual en esta sucursal: 7.0 uds'), findsOneWidget);
  });

  testWidgets('Añadir limpia la cantidad para cargar la siguiente línea',
      (tester) async {
    await montar(tester);
    await seleccionarAplique(tester, 'Flor');
    await seleccionarColor(tester, 'Rojo (stock: 7.0)');
    await tester.enterText(find.byType(TextFormField), '3');

    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();

    final campo = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(campo.controller!.text, isEmpty);
    expect(cubit.state.cantidad, isEmpty);
  });

  testWidgets(
      'tocar Fecha abre el calendario y la producción se registra en el día '
      'elegido', (tester) async {
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

    await seleccionarAplique(tester, 'Flor');
    await seleccionarColor(tester, 'Rojo (stock: 7.0)');
    await tester.enterText(find.byType(TextFormField), '2');
    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repo.produccionesCreadas.single['fecha'], DateTime(2024, 3, 20));
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

  testWidgets('Guardar sin líneas avisa y no registra nada', (tester) async {
    await montar(tester);

    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Añada al menos una línea al listado'), findsOneWidget);
    expect(repo.produccionesCreadas, isEmpty);
  });

  testWidgets(
      'si falla el registro muestra el error y conserva las líneas para '
      'reintentar', (tester) async {
    await montar(tester);
    await seleccionarAplique(tester, 'Flor');
    await seleccionarColor(tester, 'Rojo (stock: 7.0)');
    await tester.enterText(find.byType(TextFormField), '3');
    await tester.tap(find.text('Añadir'));
    await tester.pumpAndSettle();

    repo.error = Exception('Sin conexión');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Producción registrada, stock actualizado'), findsNothing);
    expect(find.text('3.0 uds'), findsOneWidget);
    expect(cubit.state.detProducciones, hasLength(1));
    expect(cubit.state.isSubmitting, isFalse);
  });
}
