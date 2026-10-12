@Tags(['golden'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Repo cuyo listado de apliques queda pendiente hasta completar [carga].
class _RepoLento extends FakeApliquesRepository {
  final carga = Completer<List<Aplique>>();

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) => carga.future;
}

void main() {
  final apliques = [
    Aplique(id: 1, nombre: 'Flor bordada 10x10', costoFabricacion: 12.5),
    Aplique(id: 2, nombre: 'Corazón 5x5', costoFabricacion: 4),
    Aplique(id: 3, nombre: 'Mariposa lentejuela 8x6', costoFabricacion: 9.5),
  ];
  // El fake devuelve estos colores para cualquier aplique; la pantalla solo
  // ofrece los vinculados (Blanco queda afuera).
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo', hex: '#C62828', vinculado: true),
    ColorItem(id: 2, nombre: 'Azul marino', hex: '#1A237E', vinculado: true),
    ColorItem(id: 3, nombre: 'Blanco', hex: '#FFFFFF', vinculado: false),
    ColorItem(id: 4, nombre: 'Dorado', hex: '#D4AF37', vinculado: true),
  ];
  const stock = [
    StockAplique(
        apliqueId: 1,
        colorId: 1,
        colorNombre: 'Rojo',
        hex: '#C62828',
        stock: 24),
    StockAplique(
        apliqueId: 1,
        colorId: 2,
        colorNombre: 'Azul marino',
        hex: '#1A237E',
        stock: 10),
    StockAplique(
        apliqueId: 2,
        colorId: 2,
        colorNombre: 'Azul marino',
        hex: '#1A237E',
        stock: 3),
  ];

  FakeApliquesRepository repoConDatos() => FakeApliquesRepository(
        apliques: apliques,
        colores: colores,
        stock: stock,
      );

  Future<void> montar(
    WidgetTester tester,
    FakeApliquesRepository repo, {
    bool asentar = true,
  }) async {
    final cubit = ProduccionFormCubit(apliquesRepository: repo, idsucursal: 1);
    addTearDown(cubit.close);
    // La fecha arranca en DateTime.now(): se fija para que la captura no
    // cambie de un día a otro
    cubit.onFechaChanged(DateTime(2026, 10, 3));
    await montarParaCaptura(
      tester,
      BlocProvider.value(value: cubit, child: ProduccionScreen()),
      asentar: asentar,
    );
  }

  Future<void> abrirAplique(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownMenu<Aplique>));
    await tester.pumpAndSettle();
  }

  Future<void> abrirColor(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownMenu<ColorItem>));
    await tester.pumpAndSettle();
  }

  Future<void> elegirAplique(WidgetTester tester, String nombre) async {
    await abrirAplique(tester);
    await tester.tap(find.text(nombre).last);
    await tester.pumpAndSettle();
  }

  Future<void> elegirColor(WidgetTester tester, String texto) async {
    await abrirColor(tester);
    await tester.tap(find.text(texto).last);
    await tester.pumpAndSettle();
  }

  Future<void> escribirCantidad(WidgetTester tester, String cantidad) async {
    await tester.enterText(find.byType(TextFormField), cantidad);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, String boton) async {
    await tester.tap(find.text(boton));
    await tester.pumpAndSettle();
  }

  testWidgets('formulario inicial: sin aplique ni color', (tester) async {
    await montar(tester, repoConDatos());

    await compararCaptura('produccion_screen_inicial');
  });

  testWidgets('selector de aplique desplegado', (tester) async {
    await montar(tester, repoConDatos());
    await abrirAplique(tester);

    await compararCaptura('produccion_screen_selector_aplique');
  });

  testWidgets('selector de color: solo los vinculados, con su stock',
      (tester) async {
    await montar(tester, repoConDatos());
    await elegirAplique(tester, 'Flor bordada 10x10');
    await abrirColor(tester);

    await compararCaptura('produccion_screen_selector_color');
  });

  testWidgets('líneas añadidas al listado y stock actual del color',
      (tester) async {
    await montar(tester, repoConDatos());
    await elegirAplique(tester, 'Corazón 5x5');
    await elegirColor(tester, 'Azul marino (stock: 3.0)');
    await escribirCantidad(tester, '6');
    await tocar(tester, 'Añadir');
    await elegirAplique(tester, 'Flor bordada 10x10');
    await elegirColor(tester, 'Rojo (stock: 24.0)');
    await escribirCantidad(tester, '12');
    await tocar(tester, 'Añadir');

    await compararCaptura('produccion_screen_con_lineas');
  });

  testWidgets('Guardar registra el lote y avisa', (tester) async {
    await montar(tester, repoConDatos());
    await elegirAplique(tester, 'Flor bordada 10x10');
    await elegirColor(tester, 'Rojo (stock: 24.0)');
    await escribirCantidad(tester, '12');
    await tocar(tester, 'Añadir');
    await tocar(tester, 'Guardar');

    await compararCaptura('produccion_screen_guardada');
  });

  testWidgets('error: Añadir sin elegir aplique', (tester) async {
    await montar(tester, repoConDatos());
    await tocar(tester, 'Añadir');

    await compararCaptura('produccion_screen_error_sin_aplique');
  });

  testWidgets('error: cantidad en 0', (tester) async {
    await montar(tester, repoConDatos());
    await elegirAplique(tester, 'Flor bordada 10x10');
    await elegirColor(tester, 'Azul marino (stock: 10.0)');
    await escribirCantidad(tester, '0');
    await tocar(tester, 'Añadir');

    await compararCaptura('produccion_screen_error_cantidad');
  });

  testWidgets('error: Guardar con el listado vacío', (tester) async {
    await montar(tester, repoConDatos());
    await tocar(tester, 'Guardar');

    await compararCaptura('produccion_screen_error_sin_lineas');
  });

  testWidgets('cargando', (tester) async {
    final repo = _RepoLento();
    await montar(tester, repo, asentar: false);
    // En el instante 0 el arco del spinner mide 0: se avanza un tramo fijo
    await tester.pump(const Duration(milliseconds: 400));

    // Se libera la carga aunque la captura falle (con un Bloc, su close()
    // esperaría el handler pendiente y el test se colgaría).
    try {
      await compararCaptura('produccion_screen_cargando');
    } finally {
      repo.carga.complete(const []);
    }
    await tester.pumpAndSettle();
  });
}
