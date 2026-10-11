@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:textiles_app/features/dashboard/presentation/screens/dashboard_screen.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

/// Repo cuyas cuatro RPC quedan pendientes hasta completar [espera].
class _RepoLento extends FakeDashboardRepository {
  final espera = Completer<void>();

  @override
  Future<List<TopProducto>> getTopProductos(
      {required DateTime desde, required DateTime hasta}) async {
    await espera.future;
    return super.getTopProductos(desde: desde, hasta: hasta);
  }

  @override
  Future<List<TopProducto>> getTopApliques(
      {required DateTime desde, required DateTime hasta}) async {
    await espera.future;
    return super.getTopApliques(desde: desde, hasta: hasta);
  }

  @override
  Future<ResumenVentas> getResumenVentas(
      {required DateTime desde, required DateTime hasta}) async {
    await espera.future;
    return super.getResumenVentas(desde: desde, hasta: hasta);
  }

  @override
  Future<ResumenVentas> getResumenVentasApliques(
      {required DateTime desde, required DateTime hasta}) async {
    await espera.future;
    return super.getResumenVentasApliques(desde: desde, hasta: hasta);
  }
}

/// La Roboto del SDK no trae la flecha "→" del período (en el celular la
/// dibuja la fuente de respaldo del sistema) y flutter_tester no busca otra
/// fuente: saldría un cuadrado vacío. Se carga Arial de Windows como respaldo
/// (las capturas son de Windows); si no está, la flecha queda como cuadrado.
Future<List<String>> _cargarRespaldoDeFlecha() async {
  final windows = Platform.environment['WINDIR'] ?? r'C:\Windows';
  final arial = File('$windows/Fonts/arial.ttf');
  if (!arial.existsSync()) return const [];
  final fuente = FontLoader('RespaldoFlecha')
    ..addFont(Future.value(ByteData.sublistView(arial.readAsBytesSync())));
  await fuente.load();
  return const ['RespaldoFlecha'];
}

/// [pantalla] con la fuente de respaldo en el texto del tema: solo cambia
/// los glifos que Roboto no tiene.
Widget _conRespaldo(Widget pantalla, List<String> respaldo) => Builder(
      builder: (context) {
        final tema = Theme.of(context);
        return Theme(
          data: tema.copyWith(
            textTheme: tema.textTheme.apply(fontFamilyFallback: respaldo),
          ),
          child: pantalla,
        );
      },
    );

void main() {
  late List<String> respaldo;
  setUpAll(() async => respaldo = await _cargarRespaldoDeFlecha());

  // Las RPC devuelven los rankings ordenados por total vendido
  const topTelas = [
    TopProducto(nombre: 'Lino', totalVendido: 4280.5, totalCantidad: 214.5),
    TopProducto(nombre: 'Seda', totalVendido: 3150, totalCantidad: 90),
    TopProducto(nombre: 'Gabardina', totalVendido: 2875, totalCantidad: 230),
    TopProducto(nombre: 'Tul', totalVendido: 1240, totalCantidad: 310),
    TopProducto(nombre: 'Raso', totalVendido: 980, totalCantidad: 70),
    TopProducto(nombre: 'Popelina', totalVendido: 615.75, totalCantidad: 82.5),
  ];
  const topApliques = [
    TopProducto(
        nombre: 'Flor bordada 10x10', totalVendido: 1250, totalCantidad: 50),
    TopProducto(nombre: 'Corazón 5x5', totalVendido: 640, totalCantidad: 80),
    TopProducto(nombre: 'Mariposa 8x6', totalVendido: 555, totalCantidad: 30),
    TopProducto(nombre: 'Estrella 4x4', totalVendido: 210, totalCantidad: 42),
  ];
  const resumenTelas =
      ResumenVentas(total: 13056.25, ganancias: 3920.4, descuento: 85);
  const resumenApliques =
      ResumenVentas(total: 2635, ganancias: 1180, descuento: 20);

  // Período fijo: el default (primer día del mes → hoy) usa DateTime.now()
  final desde = DateTime(2026, 9, 1);
  final hasta = DateTime(2026, 9, 30);

  FakeDashboardRepository conVentas() => FakeDashboardRepository(
        topTelas: topTelas,
        topApliques: topApliques,
        resumenTelas: resumenTelas,
        resumenApliques: resumenApliques,
      );

  Future<void> montar(
    WidgetTester tester,
    FakeDashboardRepository repo, {
    bool asentar = true,
  }) async {
    final cubit = DashboardCubit(repository: repo);
    addTearDown(cubit.close);
    final carga = cubit.cambiarRango(desde, hasta);
    if (asentar) await carga;
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: cubit,
        child: _conRespaldo(const DashboardScreen(), respaldo),
      ),
      asentar: asentar,
    );
  }

  Future<void> tocar(WidgetTester tester, String texto) async {
    await tester.tap(find.text(texto).hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets('Telas por total vendido', (tester) async {
    await montar(tester, conVentas());

    await compararCaptura('dashboard_telas_por_monto');
  });

  testWidgets('Telas por cantidad (metros)', (tester) async {
    await montar(tester, conVentas());
    await tocar(tester, 'Por cantidad');

    await compararCaptura('dashboard_telas_por_cantidad');
  });

  testWidgets('Apliques por total vendido', (tester) async {
    await montar(tester, conVentas());
    await tocar(tester, 'Apliques');

    await compararCaptura('dashboard_apliques_por_monto');
  });

  testWidgets('Apliques por cantidad (unidades)', (tester) async {
    await montar(tester, conVentas());
    await tocar(tester, 'Apliques');
    await tocar(tester, 'Por cantidad');

    await compararCaptura('dashboard_apliques_por_cantidad');
  });

  testWidgets('período sin ventas', (tester) async {
    await montar(tester, FakeDashboardRepository());

    await compararCaptura('dashboard_sin_ventas');
  });

  testWidgets('cargando', (tester) async {
    final lento = _RepoLento()
      ..topTelas = topTelas
      ..topApliques = topApliques
      ..resumenTelas = resumenTelas
      ..resumenApliques = resumenApliques;
    await montar(tester, lento, asentar: false);
    // Avanza el reloj de prueba para que el arco del loader se vea (en t=0
    // es un punto); el tiempo es falso, así que la captura es fija.
    await tester.pump(const Duration(milliseconds: 400));

    await compararCaptura('dashboard_cargando');

    lento.espera.complete();
    await tester.pumpAndSettle();
  });
}
