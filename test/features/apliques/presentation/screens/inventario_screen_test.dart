import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/inventario_cubit.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../../../../helpers/fake_repositories.dart';

/// No responde el inventario hasta que se complete [respuesta].
class _RepoLento extends FakeApliquesRepository {
  final respuesta = Completer<void>();

  _RepoLento({super.inventarioConVentas});

  @override
  Future<List<StockConVentas>> getInventarioConVentas(int sucursalId,
      {required DateTime desde, required DateTime hasta}) async {
    await respuesta.future;
    return super.getInventarioConVentas(sucursalId, desde: desde, hasta: hasta);
  }
}

StockConVentas _item(String aplique, String color,
        {double stock = 0, double vendidas = 0, double vendidasOtras = 0}) =>
    StockConVentas(
      apliqueId: aplique.hashCode,
      aplique: aplique,
      colorId: color.hashCode,
      color: color,
      hex: 'C0392B',
      stock: stock,
      vendidas: vendidas,
      vendidasOtras: vendidasOtras,
    );

void main() {
  // Rojo: mínimo 23, quedan 3 → hacer 43. Celeste: mínimo 5, quedan 0 → 10.
  // Blanco sobra; Perla no se vende.
  final inventario = [
    _item('Flor Grande', 'Blanco', stock: 40, vendidas: 16),
    _item('Flor Grande', 'Rojo', stock: 3, vendidas: 36.4),
    _item('Flor Pequeña', 'Celeste', stock: 0, vendidas: 8),
    _item('Mariposa', 'Perla', stock: 5),
  ];

  late FakeApliquesRepository repo;
  late List<(Uint8List, String)> compartidos;
  late bool compartePdf;
  String? copiado;

  setUp(() {
    repo = FakeApliquesRepository(inventarioConVentas: inventario);
    compartidos = [];
    compartePdf = true;
    copiado = null;
  });

  Future<void> montar(WidgetTester tester, {bool esperar = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
      if (llamada.method == 'Clipboard.setData') {
        copiado = (llamada.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    // El SucursalesBloc es global en la app (main.dart): de ahí sale el nombre
    final sucursales = SucursalesBloc(
      sucursalesRepository: FakeSucursalesRepository(sucursales: [
        Sucursal(id: 1, nombre: 'Shopping Miami'),
        Sucursal(id: 2, nombre: 'Ramada'),
      ]),
    );
    addTearDown(sucursales.close);
    final cubit = InventarioCubit(
      apliquesRepository: repo,
      idsucursal: 2,
      hoy: () => DateTime(2026, 10, 15),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sucursales),
        BlocProvider.value(value: cubit),
      ],
      child: MaterialApp(
        home: InventarioScreen(
          idsucursal: 2,
          compartirPdf: (pdf, nombre) async {
            compartidos.add((pdf, nombre));
            return compartePdf;
          },
        ),
      ),
    ));
    if (esperar) await tester.pumpAndSettle();
  }

  // FilledButton.icon es una subclase privada: byType exacto no la encuentra
  Finder boton(String texto) => find.ancestor(
      of: find.text(texto),
      matching: find.byWidgetPredicate((w) => w is FilledButton));
  Finder copiar() => find.widgetWithIcon(IconButton, Icons.copy_rounded);

  testWidgets('muestra la sucursal, el resumen y solo los faltantes',
      (tester) async {
    await montar(tester);

    expect(find.text('Inventario'), findsOneWidget);
    expect(find.text('Ramada'), findsOneWidget);
    expect(find.text('2 para reponer'), findsOneWidget);
    expect(find.text('Hacer 53 en total'), findsOneWidget);
    expect(find.text('Faltan (2)'), findsOneWidget);
    expect(find.text('Todos (4)'), findsOneWidget);
    // Por aplique, como el PDF: Flor Grande antes que Flor Pequeña
    expect(
        tester.getTopLeft(find.text('Rojo · vende 9.1 por semana')).dy,
        lessThan(
            tester.getTopLeft(find.text('Celeste · vende 2 por semana')).dy));
    expect(find.text('43'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Quedan 3 · mínimo 23'), findsOneWidget);
    expect(find.textContaining('Blanco'), findsNothing);
    expect(find.textContaining('Perla'), findsNothing);
  });

  testWidgets('"Todos" agrega lo que sobra y lo que no se vende',
      (tester) async {
    await montar(tester);

    await tester.tap(find.text('Todos (4)'));
    await tester.pumpAndSettle();

    expect(find.text('Blanco · vende 4 por semana'), findsOneWidget);
    expect(find.text('Perla · sin ventas en 4 semanas'), findsOneWidget);
    expect(find.text('Quedan 5'), findsOneWidget,
        reason: 'sin ventas no tiene mínimo');
    expect(find.text('Hacer'), findsNWidgets(2),
        reason: 'solo los faltantes dicen cuánto hacer');
  });

  testWidgets('"Compartir PDF" comparte el PDF de faltantes de la sucursal',
      (tester) async {
    await montar(tester);

    // El PDF se arma de verdad (async real, fuera del reloj falso)
    await tester.runAsync(() async {
      await tester.tap(boton('Compartir PDF'));
      while (compartidos.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    final (pdf, nombre) = compartidos.single;
    expect(nombre, 'faltantes_ramada_2026-10-15.pdf');
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(find.textContaining('No se pudo compartir'), findsNothing);
  });

  testWidgets('si no se puede compartir, avisa que se puede copiar',
      (tester) async {
    compartePdf = false;
    await montar(tester);

    await tester.runAsync(() async {
      await tester.tap(boton('Compartir PDF'));
      while (compartidos.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();

    expect(find.text('No se pudo compartir el PDF: usá "Copiar lista"'),
        findsOneWidget);
  });

  testWidgets('"Copiar lista" deja el mismo mensaje en el portapapeles',
      (tester) async {
    await montar(tester);

    await tester.tap(copiar());
    await tester.pump();

    expect(copiado, startsWith('*Huantex – Faltantes Ramada* (15/10/2026)'));
    expect(copiado, contains('Total a hacer: 53'));
    // Ordenado para el fabricante: por aplique, no por urgencia
    expect(copiado!.indexOf('Flor Grande – Rojo'),
        lessThan(copiado!.indexOf('Flor Pequeña – Celeste')));
    expect(find.text('Lista copiada: pegala en WhatsApp'), findsOneWidget);
  });

  testWidgets('si no falta nada lo dice y no deja enviar ni copiar',
      (tester) async {
    repo.inventarioConVentas = [
      _item('Flor Grande', 'Blanco', stock: 40, vendidas: 16)
    ];
    await montar(tester);

    expect(find.text('No falta nada'), findsOneWidget);
    expect(find.text('Todo alcanza para más de 2.5 semanas de venta.'),
        findsOneWidget);
    // La lista de faltantes vacía no queda en blanco
    expect(find.text('Tocá "Todos" para ver el stock de cada color.'),
        findsOneWidget);
    expect(
        tester.widget<FilledButton>(boton('Compartir PDF')).onPressed, isNull);
    expect(tester.widget<IconButton>(copiar()).onPressed, isNull);
  });

  testWidgets('una tienda sin ventas propias avisa que es una estimación',
      (tester) async {
    repo.inventarioConVentas = [
      _item('Flor Grande', 'Rojo', vendidasOtras: 8),
    ];
    await montar(tester);

    expect(find.textContaining('se estima con lo que venden las otras'),
        findsOneWidget);
    expect(find.text('1 para reponer'), findsOneWidget);
    // La venta no es de esta tienda: no dice "vende"
    expect(find.text('Rojo · se estiman 2 por semana'), findsOneWidget);
  });

  testWidgets('sin apliques en el inventario lo dice (no "no falta nada")',
      (tester) async {
    repo.inventarioConVentas = const [];
    await montar(tester);

    expect(find.text('Esta tienda no tiene apliques en el inventario.'),
        findsOneWidget);
    expect(find.text('No falta nada'), findsNothing);
    expect(find.text('Faltan (0)'), findsNothing);
  });

  testWidgets('sin conexión avisa del error y reintentar recupera',
      (tester) async {
    repo.error = Exception('Sin conexión');
    await montar(tester);

    expect(find.text('No se pudo cargar el inventario. Revisá la conexión.'),
        findsOneWidget);
    expect(find.text('No falta nada'), findsNothing);
    expect(
        tester.widget<FilledButton>(boton('Compartir PDF')).onPressed, isNull);

    repo.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('2 para reponer'), findsOneWidget);
  });

  testWidgets('mientras carga muestra el progreso y no deja enviar',
      (tester) async {
    final lento = _RepoLento(inventarioConVentas: inventario);
    repo = lento;
    await montar(tester, esperar: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
        tester.widget<FilledButton>(boton('Compartir PDF')).onPressed, isNull);

    lento.respuesta.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('2 para reponer'), findsOneWidget);
  });
}
