@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/bloc.dart';

import '../concurrencia/datos.dart';
import '../concurrencia/operaciones.dart';
import 'celular.dart';
import 'red_con_fallas.dart';

/// Venta de apliques con la red cortándose: `VentaApliquesFormCubit` →
/// `VentasApliquesDatasourceImpl.createVentaAplique` → RPC
/// `crear_venta_apliques`, con los mismos objetos que arma la ruta
/// `/venta-apliques/registro/:idsucursal`. La única diferencia con la app es
/// la fecha: el datasource manda `DateTime.now()` y la red la reemplaza por
/// [fechaRD] (`RedConFallas.fijarParametro`) para no meterse en el dashboard.
void main() {
  late Celular celular;
  late DatosRD datos;
  RedConFallas red() => celular.red;

  setUpAll(() async {
    celular = await Celular.abrir();
    datos = DatosRD(celular.base);
    red().fijarParametro(
        'crear_venta_apliques', 'p_fecha', fechaRD.toIso8601String());
  });

  tearDownAll(() async {
    try {
      await datos.darDeBaja();
    } finally {
      await celular.cerrar();
    }
  });

  tearDown(() => red()
    ..restablecer()
    ..registro.clear());

  const stockInicial = 10;
  const cantidad = 2;
  const precio = 12;
  const costo = 5;

  /// Aplique+color nuevo con [stockInicial] fabricado y el formulario de
  /// venta con una línea de [cantidad] a [precio], elegidos con los mismos
  /// datos que muestra la pantalla (aplique de `getApliques`, color y stock
  /// de `getStock`).
  Future<(ApliqueEnSucursal, VentaApliquesFormCubit)> carritoListo() async {
    final p = await datos.apliqueEnSucursalNueva(costo: costo);
    await fabricar(celular.base,
        sucursal: p.sucursal,
        aplique: p.aplique,
        color: p.color,
        cantidad: stockInicial,
        fecha: fechaRD);

    final apliques = ApliquesRepositoryImpl(ApliquesDatasourceImpl());
    final cubit = VentaApliquesFormCubit(
      ventasApliquesRepository:
          VentasApliquesRepositoryImpl(VentasApliquesDatasourceImpl()),
      idsucursal: p.sucursal,
    );
    addTearDown(cubit.close);
    final aplique =
        (await apliques.getApliques()).singleWhere((a) => a.id == p.aplique);
    final stock = (await apliques.getStock(p.sucursal))
        .singleWhere((s) => s.apliqueId == p.aplique && s.colorId == p.color);
    cubit
      ..onApliqueChanged(aplique)
      ..onColorChanged(stock)
      ..onCantidadChanged('$cantidad')
      ..onPrecioChanged('$precio');
    expect(cubit.addDetalle(), isNull);
    red().registro.clear();
    return (p, cubit);
  }

  /// Lo que quedó en la base, en una sola comparación: si falla, el mensaje
  /// muestra todo lo que quedó (la evidencia del bug).
  Future<void> verificarVendidoUnaVez(ApliqueEnSucursal p) async {
    final db = celular.base;
    final ventas = await ventasApliquesDelDia(db, p.sucursal, fechaRD);
    final lineas = [
      for (final v in ventas) ...await lineasVentaApliques(db, v['id'] as int),
    ];
    expect({
      'stock': await stockDe(db, p),
      'ventas del día': ventas.length,
      'total de la venta': sumaCentavos(ventas, 'total') / 100,
      'ganancias de la venta': sumaCentavos(ventas, 'ganancias') / 100,
      'líneas': lineas.length,
      'unidades vendidas':
          lineas.fold<double>(0, (suma, l) => suma + numero(l['cantidad'])),
    }, {
      'stock': stockInicial - cantidad,
      'ventas del día': 1,
      'total de la venta': cantidad * precio,
      'ganancias de la venta': cantidad * (precio - costo),
      'líneas': 1,
      'unidades vendidas': cantidad,
    }, reason: 'el stock se descuenta y la venta del día suma una sola vez');
  }

  test(
      'respuesta perdida: la app ve un error y conserva el carrito, pero la '
      'venta ya quedó registrada en la base', () async {
    final (p, cubit) = await carritoListo();
    red().perderRespuesta(cuando: Cuando.rpc('crear_venta_apliques'));

    expect(await cubit.onFormSubmit(), isFalse);

    expect(red().perdidas, ['rpc/crear_venta_apliques']);
    expect(cubit.state.detalles, hasLength(1),
        reason: 'el carrito queda para volver a tocar Guardar');
    // El commit no se deshace: la base ya descontó el stock y sumó la venta.
    await verificarVendidoUnaVez(p);
  });

  test(
      'respuesta perdida y el usuario vuelve a tocar Guardar: el stock se '
      'descuenta una sola vez y la venta del día suma una sola vez', () async {
    final (p, cubit) = await carritoListo();
    red().perderRespuesta(cuando: Cuando.rpc('crear_venta_apliques'));
    expect(await cubit.onFormSubmit(), isFalse);

    // Volvió la señal: el mismo carrito, "Guardar" otra vez.
    expect(await cubit.onFormSubmit(), isTrue);

    expect(red().llegaron,
        ['rpc/crear_venta_apliques', 'rpc/crear_venta_apliques']);
    await verificarVendidoUnaVez(p);
  },
      // bug: supabase/migrations/20261007000000_venta_apliques_colores_vinculados.sql:40 — crear_venta_apliques no es idempotente: el reintento (lib/features/apliques/presentation/bloc/venta_apliques_form_cubit.dart:192 manda el mismo carrito sin id de operación) vuelve a sumar la venta del día, la línea y a descontar el stock (queda 6 en vez de 8, total 48 en vez de 24)
      skip: bugConocido);

  test(
      'sin conexión: falla limpia (no llega nada a la base), conserva el '
      'carrito y el reintento con señal vende una vez', () async {
    final (p, cubit) = await carritoListo();
    red().cortar();

    expect(await cubit.onFormSubmit(), isFalse);

    expect(red().llegaron, isEmpty);
    expect(red().cortadas, ['rpc/crear_venta_apliques']);
    expect(cubit.state.detalles, hasLength(1));
    expect(await stockDe(celular.base, p), stockInicial);
    expect(
        await ventasApliquesDelDia(celular.base, p.sucursal, fechaRD), isEmpty);

    red().restablecer();
    expect(await cubit.onFormSubmit(), isTrue);
    await verificarVendidoUnaVez(p);
  });
}
