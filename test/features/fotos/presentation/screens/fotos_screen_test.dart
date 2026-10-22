import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:textiles_app/features/fotos/fotos.dart';

import '../../../../helpers/fake_repositories.dart';
import '../../../../helpers/imagenes.dart';

void main() {
  late FakeFotosRepository repo;
  late List<ImageSource> origenes;
  FotoElegida? eleccion;
  Exception? errorAlElegir;

  const fotos = [
    Foto(id: 1, url: 'https://example.com/1.jpg'),
    Foto(id: 2, url: 'https://example.com/2.jpg'),
  ];
  const elegida = FotoElegida(bytes: [1, 2, 3], extension: 'jpg');

  setUp(() {
    repo = FakeFotosRepository(nombre: 'Lino', fotos: fotos);
    origenes = [];
    eleccion = elegida;
    errorAlElegir = null;
  });

  Future<FotosCubit> montar(
    WidgetTester tester, {
    ProductoConFotos producto = ProductoConFotos.tela,
    bool conCamara = true,
    FotosRepository? repositorio,
    bool esperar = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    liberarImagenesAlTerminar(tester);
    final cubit = FotosCubit(
        fotosRepository: repositorio ?? repo, producto: producto, id: 7);
    addTearDown(cubit.close);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: FotosScreen(
          producto: producto,
          conCamara: conCamara,
          imagen: imagenDePrueba,
          elegirFoto: (origen) async {
            origenes.add(origen);
            if (errorAlElegir != null) throw errorAlElegir!;
            return eleccion;
          },
        ),
      ),
    ));
    if (esperar) await tester.pumpAndSettle();
    return cubit;
  }

  Finder boton(String texto) => find.ancestor(
      of: find.text(texto),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));

  testWidgets('título con el nombre, una miniatura por foto y la principal',
      (tester) async {
    await montar(tester);

    expect(find.text('Lino'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('Principal'), findsOneWidget);
    expect(find.byTooltip('Quitar foto'), findsNWidgets(2));
  });

  testWidgets('sin nombre usa el título genérico de tela o de aplique',
      (tester) async {
    repo.nombre = '';
    await montar(tester, producto: ProductoConFotos.aplique);

    expect(find.text('Fotos del aplique'), findsOneWidget);
  });

  testWidgets('sin fotos lo dice y aclara cuál se ve en la web',
      (tester) async {
    repo.fotos = [];
    await montar(tester);

    expect(find.textContaining('Todavía no tiene fotos.'), findsOneWidget);
    expect(find.textContaining('La primera es la que se ve en la web.'),
        findsOneWidget);
  });

  testWidgets('"Galería" elige de la galería y sube la foto', (tester) async {
    await montar(tester);

    await tester.tap(boton('Galería'));
    await tester.pumpAndSettle();

    expect(origenes, [ImageSource.gallery]);
    expect(repo.subirCalls.single, (ProductoConFotos.tela, 7, elegida));
    expect(find.byType(Image), findsNWidgets(3));
  });

  testWidgets('"Cámara" saca la foto con la cámara', (tester) async {
    await montar(tester, producto: ProductoConFotos.aplique);

    await tester.tap(boton('Cámara'));
    await tester.pumpAndSettle();

    expect(origenes, [ImageSource.camera]);
    expect(repo.subirCalls.single.$1, ProductoConFotos.aplique);
  });

  testWidgets('sin cámara (Windows) solo ofrece la galería', (tester) async {
    await montar(tester, conCamara: false);

    expect(boton('Galería'), findsOneWidget);
    expect(find.text('Cámara'), findsNothing);
  });

  testWidgets('si no elige nada no sube', (tester) async {
    eleccion = null;
    await montar(tester);

    await tester.tap(boton('Galería'));
    await tester.pumpAndSettle();

    expect(repo.subirCalls, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('si no se puede abrir la galería (permiso) avisa',
      (tester) async {
    errorAlElegir = Exception('permiso negado');
    await montar(tester);

    await tester.tap(boton('Galería'));
    await tester.pump();

    expect(find.text('No se pudo abrir la foto'), findsOneWidget);
    expect(repo.subirCalls, isEmpty);
  });

  testWidgets('si la subida falla avisa y no agrega la foto', (tester) async {
    repo.errorAlSubir = Exception('sin conexión');
    await montar(tester);

    await tester.tap(boton('Galería'));
    await tester.pump();

    expect(find.text('No se pudo subir la foto. Revisá la conexión.'),
        findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('mientras sube muestra el progreso y deshabilita los botones',
      (tester) async {
    final lento = _RepoLento(nombre: 'Lino', fotos: fotos);
    await montar(tester, repositorio: lento);

    await tester.tap(boton('Galería'));
    await tester.pump();

    expect(find.text('Subiendo foto…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(boton('Galería')).onPressed,
        isNull);
    expect(
        tester.widget<ButtonStyleButton>(boton('Cámara')).onPressed, isNull);

    lento.espera.complete();
    await tester.pumpAndSettle();

    expect(find.text('Subiendo foto…'), findsNothing);
    expect(find.byType(Image), findsNWidgets(3));
  });

  testWidgets('quitar pide confirmación y saca la foto', (tester) async {
    await montar(tester);

    await tester.tap(find.byTooltip('Quitar foto').first);
    await tester.pumpAndSettle();
    expect(find.text('Quitar foto'), findsWidgets);
    expect(find.text('Deja de verse en la app y en la web.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Quitar'));
    await tester.pumpAndSettle();

    expect(repo.quitarCalls, [(ProductoConFotos.tela, 1)]);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Principal'), findsOneWidget,
        reason: 'la que queda pasa a ser la principal');
  });

  testWidgets('cancelar la confirmación no quita nada', (tester) async {
    await montar(tester);

    await tester.tap(find.byTooltip('Quitar foto').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(repo.quitarCalls, isEmpty);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('sin conexión avisa del error y reintentar recupera',
      (tester) async {
    repo.error = Exception('sin conexión');
    await montar(tester);

    expect(find.text('No se pudieron cargar las fotos. Revisá la conexión.'),
        findsOneWidget);
    expect(find.text('Galería'), findsNothing);

    repo.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsNWidgets(2));
  });
}

/// Sube recién cuando se completa [espera].
class _RepoLento extends FakeFotosRepository {
  final espera = Completer<void>();

  _RepoLento({super.nombre, super.fotos});

  @override
  Future<Foto> subirFoto(
      ProductoConFotos producto, int id, FotoElegida foto) async {
    await espera.future;
    return super.subirFoto(producto, id, foto);
  }
}
