// Flujos de los macro-benchmarks: cada uno mide latencias (toque → dato
// visible, `medirLatencia`) y fluidez (frames, `medirFluidez`) de una parte de
// la app. Comandos y claves: cabecera de app_benchmark.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';

import '../../integration_test/datos.dart';
import '../../integration_test/helpers.dart';
import 'medicion.dart';

/// Tarjetas de sucursal: el inicio (venta de telas) y la gestión.
final _tarjetasSucursal = find.byType(ItemDashboard);

/// Botón de las tarjetas de los listados de telas y apliques.
final _tarjetasProducto = find.text('Modificar');

/// Los colores del listado de colores (ninguna otra pantalla del menú tiene).
final _muestrasColor = find.byType(CircleAvatar);

/// Las tarjetas de resumen del dashboard solo están con los datos cargados
/// ("Por cantidad" se ve también mientras carga).
final _dashboardCargado = find.text('Ganancias');

/// Sesión iniciada y la app en el inicio con las sucursales cargadas.
Future<void> _entrar(WidgetTester tester) async {
  await iniciarSesionDirecto();
  await montarApp(tester);
  await esperarHasta(tester, _tarjetasSucursal);
}

Future<void> _irAlInicio(WidgetTester tester) async {
  await irDesdeMenu(tester, 'Venta telas');
  await esperarHasta(tester, _tarjetasSucursal);
}

/// Abre el menú y mide desde el toque en [opcion] hasta que aparece [listo].
/// [listo] no tiene que estar en la pantalla de partida: durante la
/// transición conviven las dos.
Future<void> _medirDesdeMenu(
    WidgetTester tester, String clave, String opcion, Finder listo) =>
    _medirOpcion(tester, clave, opcionDelMenu(opcion), listo);

/// Como [_medirDesdeMenu], con una opción del submenú "Dashboard".
Future<void> _medirDesdeDashboard(
    WidgetTester tester, String clave, String linea, Finder listo) =>
    _medirOpcion(tester, clave, opcionDelDashboard(linea), listo);

Future<void> _medirOpcion(
    WidgetTester tester, String clave, Finder opcion, Finder listo) async {
  await abrirMenu(tester);
  await tester.ensureVisible(opcion);
  await tester.pumpAndSettle();
  await medirLatencia(tester, clave, () => tester.tap(opcion), listo: listo);
  await tester.pumpAndSettle();
}

/// El dashboard de [linea] con su ranking cargado (o el aviso de que no hay
/// ventas). El resumen no sirve al pasar de un dashboard al otro: ya está en
/// la pantalla de partida.
Finder _rankingCargado(String linea) =>
    find.textContaining(RegExp('$linea (por|en el período)'));

void benchmarkLogin() {
  testWidgets('login', (tester) async {
    final email = find.byKey(const Key('login_email'));
    final password = find.byKey(const Key('login_password'));
    final ingresar = find.byKey(const Key('login_submit'));

    Future<void> formularioCompleto() async {
      // Árbol nuevo cada vez: el bloc de sucursales es global y, si
      // sobreviviera, el inicio no las volvería a pedir
      await tester.pumpWidget(const SizedBox());
      await cerrarSesionDirecto();
      await montarApp(tester);
      await escribir(tester, email, emailPrueba);
      await escribir(tester, password, passwordPrueba);
    }

    for (var i = 0; i < repeticiones; i++) {
      await formularioCompleto();
      await medirLatencia(tester, 'login_a_inicio', () => tester.tap(ingresar),
          listo: _tarjetasSucursal);
    }

    await formularioCompleto();
    await medirFluidez('login', () async {
      await tester.tap(ingresar);
      await esperarHasta(tester, _tarjetasSucursal);
      await tester.pumpAndSettle();
    });
  });
}

void benchmarkSucursales() {
  testWidgets('sucursales', (tester) async {
    await _entrar(tester);

    for (var i = 0; i < repeticiones; i++) {
      // Desde una pantalla sin tarjetas de sucursal
      await irDesdeMenu(tester, 'Colores');
      await esperarHasta(tester, _muestrasColor);
      await _medirDesdeMenu(
          tester, 'abrir_sucursales', 'Sucursales', _tarjetasSucursal);
    }

    // Gestión → formulario de una sucursal → atrás
    await medirFluidez('sucursales_navegacion', () async {
      for (var i = 0; i < 3; i++) {
        await tester.tap(_tarjetasSucursal.first);
        await esperarHasta(tester, find.text('Editar Sucursal'));
        await tester.pumpAndSettle();
        await volver(tester);
        await esperarHasta(tester, _tarjetasSucursal);
      }
    });
    await medirFluidez(
        'sucursales_scroll', () => recorrerLista(tester, veces: 3));
  });
}

void benchmarkTelas() {
  testWidgets('telas: listado, scroll y búsqueda', (tester) async {
    await _entrar(tester);

    for (var i = 0; i < repeticiones; i++) {
      if (i > 0) await _irAlInicio(tester);
      await _medirDesdeMenu(tester, 'abrir_telas', 'Telas', _tarjetasProducto);
    }

    await medirFluidez('telas_scroll', () => recorrerLista(tester));

    // Búsqueda: el filtro es en memoria, sobre las +150 telas
    final buscador = find.byType(TextField).first;
    for (var i = 0; i < repeticiones; i++) {
      final buscada = nombreMasivo('Tela', telasMasivas - i);
      await tester.tap(buscador);
      await tester.pumpAndSettle();
      await medirLatencia(
          tester, 'buscar_tela', () => tester.enterText(buscador, buscada),
          listo: textoFijo(buscada));
      await tester.enterText(buscador, '');
      await ocultarTeclado(tester);
    }

    await tester.tap(buscador);
    await tester.pumpAndSettle();
    await medirFluidez(
        'telas_busqueda', () => tipear(tester, buscador, 'bm tela 12'));
    await ocultarTeclado(tester);
  });
}

void benchmarkColores() {
  testWidgets('colores', (tester) async {
    await _entrar(tester);

    for (var i = 0; i < repeticiones; i++) {
      if (i > 0) await _irAlInicio(tester);
      await _medirDesdeMenu(tester, 'abrir_colores', 'Colores', _muestrasColor);
    }

    await medirFluidez('colores_scroll', () => recorrerLista(tester, veces: 4));
  });
}

void benchmarkApliques() {
  testWidgets('apliques: listado y scroll', (tester) async {
    await _entrar(tester);

    for (var i = 0; i < repeticiones; i++) {
      if (i > 0) await _irAlInicio(tester);
      await _medirDesdeMenu(
          tester, 'abrir_apliques', 'Apliques', _tarjetasProducto);
    }

    await medirFluidez('apliques_scroll', () => recorrerLista(tester));
  });
}

void benchmarkFabricacion() {
  testWidgets('fabricación', (tester) async {
    final datos = DatosBM();
    final sucursal = await datos.sucursal('Fabricacion');
    final aplique = await datos.aplique('Luna fab');
    final color = await datos.color('Dorado fab', hex: 'F1C40F');
    await datos.vincularColor(aplique, color);
    await _entrar(tester);

    await irDesdeMenu(tester, 'Fabricación');
    await tocar(tester, tarjeta(sucursal.nombre));
    await esperarHasta(tester, find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await esperarHasta(tester, find.byType(DropdownMenu<Aplique>));

    // El selector arma una opción por aplique activo (+150)
    await medirFluidez('fabricacion_formulario', () async {
      await elegir(tester, find.byType(DropdownMenu<Aplique>), aplique.nombre);
      await elegir(tester, find.byType(DropdownMenu<ColorItem>), color.nombre);
    });

    // Guardar → RPC registrar_produccion → la pantalla muestra el stock nuevo
    for (var i = 1; i <= repeticiones; i++) {
      await escribir(tester, campo('Cantidad fabricada'), '2');
      await tocar(tester, find.text('Añadir'));
      await asegurarVisible(tester, find.text('Guardar'));
      await medirLatencia(tester, 'registrar_fabricacion',
          () => tester.tap(find.text('Guardar')),
          listo:
              find.textContaining('Stock actual en esta sucursal: ${2 * i}'));
      await tester.pumpAndSettle();
    }
    await esperarQue(
        () async => await stockDe(sucursal, aplique, color) == 2 * repeticiones,
        descripcion: 'stock de la fabricación');
  });
}

void benchmarkVentaApliques() {
  testWidgets('venta de apliques', (tester) async {
    const stockInicial = 100;
    final datos = DatosBM();
    final sucursal = await datos.sucursal('Venta apliques');
    final aplique = await datos.aplique('Mariposa venta', costo: 5);
    final color = await datos.color('Fucsia venta', hex: 'E91E63');
    await datos.vincularColor(aplique, color);
    await datos.fabricar(sucursal, aplique, color, stockInicial);
    await _entrar(tester);

    await irDesdeMenu(tester, 'Venta apliques');
    await tocar(tester, tarjeta(sucursal.nombre));
    await esperarHasta(tester, find.byIcon(Icons.add));

    Future<void> abrirFormulario() async {
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.byType(DropdownMenu<Aplique>));
    }

    Future<void> agregarLinea() async {
      await elegir(tester, find.byType(DropdownMenu<Aplique>), aplique.nombre);
      await elegir(
          tester, find.byType(DropdownMenu<StockAplique>), color.nombre);
      await escribir(tester, campo('Cantidad'), '1');
      await escribir(tester, campo('Precio'), '12');
      await tocar(tester, find.text('Añadir'));
    }

    await abrirFormulario();
    await medirFluidez('venta_apliques_formulario', agregarLinea);

    // Confirmar → RPC crear_venta_apliques (descuenta stock) → snackbar
    for (var i = 1; i <= repeticiones; i++) {
      if (i > 1) {
        await abrirFormulario();
        await agregarLinea();
      }
      await tocar(tester, find.text('Guardar'));
      await esperarHasta(tester, find.text('Confirmar Venta'));
      await limpiarSnacks(tester);
      await medirLatencia(tester, 'registrar_venta_apliques',
          () => tester.tap(find.text('Confirmar')),
          listo: find.text(snackOk));
      await esperarHasta(tester, tarjeta(changeFormatDate(DateTime.now())));
      await tester.pumpAndSettle();
      await esperarQue(
          () async =>
              await stockDe(sucursal, aplique, color) == stockInicial - i,
          descripcion: 'stock descontado por la venta $i');
    }
  });
}

void benchmarkVentaTelas() {
  testWidgets('venta de telas', (tester) async {
    final datos = DatosBM();
    final sucursal = await datos.sucursal('Venta telas');
    final tela = await datos.tela('Lino venta', compra: 15);
    await _entrar(tester);

    await tocar(tester, tarjeta(sucursal.nombre));
    await esperarHasta(tester, find.text('Ventas'));

    Future<void> abrirFormulario() async {
      await tester.tap(find.byIcon(Icons.add));
      await esperarHasta(tester, find.byType(DropdownMenu<Tela>));
    }

    // El selector ofrece todo el catálogo (+150): la sucursal no tiene
    // telas vinculadas
    Future<void> agregarLinea() async {
      await elegir(tester, find.byType(DropdownMenu<Tela>), tela.nombre);
      await escribir(tester, campo('Precio'), '25');
      await escribir(tester, campo('Cantidad'), '1');
      await tocar(tester, find.text('Añadir'));
    }

    await abrirFormulario();
    await medirFluidez('venta_telas_formulario', agregarLinea);

    // Guardar → venta del día + RPC registrar_detalle_venta → snackbar
    for (var i = 1; i <= repeticiones; i++) {
      if (i > 1) {
        await abrirFormulario();
        await agregarLinea();
      }
      await asegurarVisible(tester, find.text('Guardar'));
      await limpiarSnacks(tester);
      await medirLatencia(tester, 'registrar_venta_telas',
          () => tester.tap(find.text('Guardar')),
          listo: find.text(snackOk));
      await esperarHasta(tester, tarjeta(changeFormatDate(DateTime.now())));
      await tester.pumpAndSettle();
    }
    await esperarQue(() async {
      final ventas = await db
          .from('ventas')
          .select('total')
          .eq('idsucursales', sucursal.id);
      return ventas.length == 1 &&
          numero(ventas.single['total']) == 25.0 * repeticiones;
    }, descripcion: 'una venta del día con las $repeticiones líneas');
  });
}

void benchmarkDashboard() {
  testWidgets('dashboard', (tester) async {
    await _entrar(tester);

    for (var i = 0; i < repeticiones; i++) {
      if (i > 0) await _irAlInicio(tester);
      await _medirDesdeDashboard(
          tester, 'cargar_dashboard', 'Telas', _dashboardCargado);
    }

    // Del submenú Telas al de Apliques (y de vuelta, sin medir)
    for (var i = 0; i < repeticiones; i++) {
      await _medirDesdeDashboard(tester, 'cargar_dashboard_apliques',
          'Apliques', _rankingCargado('apliques'));
      await irAlDashboard(tester, 'Telas');
      await esperarHasta(tester, _rankingCargado('telas'));
    }

    // Mes actual → junio de 2020 (las +150 telas del volumen) y de vuelta
    final hoy = DateTime.now();
    for (var i = 0; i < repeticiones; i++) {
      await tester.tap(find.text('Período'));
      await tester.pumpAndSettle();
      await medirRango(tester, 'cambiar_periodo', desdeMasivo, hastaMasivo,
          find.text(primeraDelRanking));
      if (i == repeticiones - 1) break;
      await tester.tap(find.text('Período'));
      await tester.pumpAndSettle();
      await elegirRango(tester, DateTime(hoy.year, hoy.month), hoy);
      await esperarHasta(tester, _dashboardCargado);
    }

    await medirFluidez('dashboard_scroll', () => recorrerLista(tester));
  });
}

void benchmarkMenu() {
  testWidgets('menú lateral', (tester) async {
    await _entrar(tester);

    await medirFluidez('menu_lateral', () async {
      for (var i = 0; i < 5; i++) {
        await abrirMenu(tester);
        tester
            .stateList<ScaffoldState>(find.byType(Scaffold))
            .firstWhere((s) => s.hasDrawer)
            .closeDrawer();
        await tester.pumpAndSettle();
      }
    });

    // Cada pantalla con sus datos cargados antes de pasar a la siguiente
    await medirFluidez('navegacion_menu', () async {
      for (final (opcion, listo) in [
        (opcionDelMenu('Telas'), _tarjetasProducto),
        (opcionDelMenu('Colores'), _muestrasColor),
        (opcionDelMenu('Apliques'), _tarjetasProducto),
        (opcionDelDashboard('Telas'), _dashboardCargado),
        (opcionDelDashboard('Apliques'), _rankingCargado('apliques')),
        (opcionDelMenu('Venta telas'), _tarjetasSucursal),
      ]) {
        await tocarEnMenu(tester, opcion);
        await esperarHasta(tester, listo);
        await tester.pumpAndSettle();
      }
    });
  });
}
