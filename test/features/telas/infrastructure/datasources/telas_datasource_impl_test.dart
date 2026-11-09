import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/telas/presentation/screens/screens.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/presentation/screens/screens.dart';

import '../../../../helpers/base_falsa.dart';
import '../../../../helpers/fake_repositories.dart';

// La regla de transición de `getTelasPorSucursal` (sin ningún vínculo activo
// en tela_sucursales se ofrece todo el catálogo) vive en el datasource: se
// prueba con el TelasDatasourceImpl real contra la BaseFalsa, que resuelve el
// embed `tela_sucursales!inner(*)` y sus filtros como PostgREST. Contra la
// base de verdad lo fija la integración (integration_test/flujos/sucursales.dart).
// El orden de los colores de una tela también lo decide el datasource: se
// prueba igual, de la pantalla a la BaseFalsa.
void main() {
  final base = usarBaseFalsa();

  Fila tela(int id, String nombre, {bool activo = true}) => {
        'id': id,
        'nombre': nombre,
        'precxmen': 30,
        'precxmay': 25,
        'precxrollo': 1000,
        'precxcompra': 18,
        'activo': activo,
      };

  Fila vinculo(int idtela, int idsucursal, {bool activo = true}) =>
      {'idtela': idtela, 'idsucursal': idsucursal, 'activo': activo};

  void cargar({required List<Fila> telas, required List<Fila> vinculos}) {
    base
      ..tabla('telas', telas)
      ..tabla('tela_sucursales', vinculos)
      ..relacion('telas', 'tela_sucursales',
          columna: 'id', referencia: 'idtela');
  }

  /// Lino (dada de baja) es la única habilitada en la sucursal 7; Seda y Tul
  /// están activas pero no se venden ahí.
  void soloTelasDadasDeBaja() => cargar(telas: [
        tela(1, 'Lino', activo: false),
        tela(2, 'Seda'),
        tela(3, 'Tul'),
      ], vinculos: [
        vinculo(1, 7),
        vinculo(2, 8),
      ]);

  List<String> nombres(List<Tela> telas) => [for (final t in telas) t.nombre];

  group('getTelasPorSucursal', () {
    test(
        'con vínculos activos solo a telas dadas de baja no ofrece ninguna '
        '(no aplica la regla de transición)', () async {
      soloTelasDadasDeBaja();

      expect(await TelasDatasourceImpl().getTelasPorSucursal(7), isEmpty);
    });

    // Los dos casos que ya fija la integración, para ver que la base falsa
    // resuelve el embed como PostgREST.
    test('sin ningún vínculo activo ofrece todo el catálogo activo', () async {
      cargar(telas: [
        tela(1, 'Lino', activo: false),
        tela(2, 'seda'),
        tela(3, 'Tul'),
      ], vinculos: [
        vinculo(2, 7, activo: false),
      ]);

      expect(nombres(await TelasDatasourceImpl().getTelasPorSucursal(7)),
          ['seda', 'Tul']);
    });

    test('con vínculos activos ofrece solo las telas activas vinculadas',
        () async {
      cargar(telas: [
        tela(1, 'Lino', activo: false),
        tela(2, 'Seda'),
        tela(3, 'Tul'),
        tela(4, 'gasa'),
      ], vinculos: [
        vinculo(1, 7),
        vinculo(3, 7),
        vinculo(4, 7),
        vinculo(2, 7, activo: false),
        vinculo(2, 8),
      ]);

      expect(nombres(await TelasDatasourceImpl().getTelasPorSucursal(7)),
          ['gasa', 'Tul']);
    });
  });

  testWidgets(
      'el selector de telas del registro de venta queda vacío si las '
      'habilitadas están todas dadas de baja', (tester) async {
    soloTelasDadasDeBaja();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Como en app_router (/det_venta/:idsucursal)
    final cubit = DetalleVentaFormCubit(
      ventasRepository: FakeVentasRepository(),
      idsucursal: 7,
    );
    final telasBloc = TelasBloc(
      telasRepository: TelasRepositoryImpl(TelasDatasourceImpl()),
      idsucursal: 7,
    );
    addTearDown(cubit.close);
    addTearDown(telasBloc.close);
    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: telasBloc),
        ],
        child: const DetVenta(),
      ),
    ));
    await tester.pumpAndSettle();

    final selector =
        tester.widget<DropdownMenu<Tela>>(find.byType(DropdownMenu<Tela>));
    expect(selector.dropdownMenuEntries, isEmpty);
    expect(telasBloc.state.telas, isEmpty);
  });

  // Spec telas, "Ver los colores de una tela": por nombre de la A a la Z sin
  // distinguir mayúsculas, como en Android. El datasource pide
  // `ascending: true` (postgrest-dart ordena descendente si no) y reordena en
  // minúsculas: la BaseFalsa ordena distinguiendo mayúsculas ("Rojo" antes
  // que "azul").
  group('colores de la tela', () {
    // Desordenados a propósito y con un nombre en minúscula; Negro está dado
    // de baja (no se lista).
    setUp(() => base
      ..tabla('telas', [tela(7, 'Lino')])
      ..tabla('colores', [
        {'id': 1, 'nombre': 'Rojo', 'hex': 'FF0000', 'activo': true},
        {'id': 2, 'nombre': 'azul', 'hex': '0000FF', 'activo': true},
        {'id': 3, 'nombre': 'Negro', 'hex': '000000', 'activo': false},
        {'id': 4, 'nombre': 'Verde', 'hex': '00FF00', 'activo': true},
      ])
      ..tabla('tela_colores', [
        {'idtela': 7, 'idcolor': 1, 'activo': true},
        {'idtela': 7, 'idcolor': 4, 'activo': false},
        {'idtela': 8, 'idcolor': 2, 'activo': true},
      ])
      ..relacion('colores', 'tela_colores',
          columna: 'id', referencia: 'idcolor'));

    test(
        'getColoresTela los trae por nombre, de la A a la Z sin distinguir '
        'mayúsculas', () async {
      final colores = await TelasDatasourceImpl().getColoresTela(7);

      expect([for (final c in colores) (c.nombre, c.vinculado)], [
        ('azul', false),
        ('Rojo', true),
        ('Verde', false),
      ]);
    });

    testWidgets('la pantalla muestra los interruptores en ese orden',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // Como en app_router (/tela-colores/:idtela)
      final cubit = TelaColoresCubit(
        telasRepository: TelasRepositoryImpl(TelasDatasourceImpl()),
        idtela: 7,
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const TelaColoresScreen(idtela: 7),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Lino'), findsOneWidget);
      expect(
          [
            for (final s in tester
                .widgetList<SwitchListTile>(find.byType(SwitchListTile)))
              ((s.title! as Text).data, s.value),
          ],
          [('azul', false), ('Rojo', true), ('Verde', false)]);
    });
  });
}
