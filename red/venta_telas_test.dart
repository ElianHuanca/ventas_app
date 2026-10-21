@Timeout(Duration(minutes: 4))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/ventas/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';

import '../concurrencia/datos.dart';
import 'celular.dart';
import 'red_con_fallas.dart';

/// Venta de telas con la red cortándose. Registrar es una cadena de llamadas
/// separadas (`DetalleVentaFormCubit.onFormSubmit`): buscar la venta del día
/// (GET `ventas`) → crearla si no hay (POST `ventas`) → las líneas (RPC
/// `registrar_detalle_venta`) → los totales (RPC `incrementar_venta`). Borrar
/// una línea (`DetalleVentasBloc.deleteDetVenta`) es otra: leer la línea →
/// DELETE → `incrementar_venta` con el delta negativo. Una falla en el medio
/// las deja a medias. Mismos objetos que las rutas `/det_venta/:idsucursal` y
/// `/det_ventas/:idventa`, con la fecha elegida en el formulario
/// ([fechaRD], como "fecha anterior").
void main() {
  late Celular celular;
  late DatosRD datos;
  RedConFallas red() => celular.red;

  setUpAll(() async {
    celular = await Celular.abrir();
    datos = DatosRD(celular.base);
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

  const metros = 2;
  const precio = 25;
  const compra = 15;

  DetalleVentaFormCubit formulario(int sucursal) {
    final cubit = DetalleVentaFormCubit(
      ventasRepository: VentasRepositoryImpl(VentasDatasourceImpl()),
      detalleVentasRepository:
          DetalleVentasRepositoryImpl(DetalleVentasDatasourceImpl()),
      idsucursal: sucursal,
    );
    addTearDown(cubit.close);
    return cubit..onFechaChanged(fechaRD);
  }

  /// Agrega al carrito [cantidad] m de [idtela] a [precioVenta], como el
  /// selector de la pantalla (nombre y precio de compra de la tela).
  Future<void> agregar(DetalleVentaFormCubit cubit, int idtela,
      {num cantidad = metros, num precioVenta = precio}) async {
    final tela =
        await TelasRepositoryImpl(TelasDatasourceImpl()).getTela(idtela);
    cubit
      ..onPrecxCompraChanged(tela.precxcompra ?? 0)
      ..onNombreChanged(tela.nombre)
      ..onIdTelasChanged(tela.id)
      ..onCantidadChanged('$cantidad')
      ..onPrecioChanged('$precioVenta')
      ..addDetalleVenta();
  }

  /// Sucursal y tela nuevas con [metros] m en el carrito.
  Future<(int, DetalleVentaFormCubit)> carritoListo() async {
    final sucursal = await datos.sucursal();
    final tela = await datos.tela(precio: precio, compra: compra);
    final cubit = formulario(sucursal);
    await agregar(cubit, tela);
    expect(cubit.state.detVentas, hasLength(1));
    red().registro.clear();
    return (sucursal, cubit);
  }

  /// La venta del día y sus líneas, en una sola comparación (si falla, el
  /// mensaje muestra todo lo que quedó): el total y las ganancias de la venta
  /// tienen que ser la suma de sus líneas y lo vendido una sola vez.
  Future<void> verificarVenta(int sucursal,
      {required int lineas,
      required num metrosVendidos,
      required num total,
      required num ganancias}) async {
    final db = celular.base;
    final ventas = await ventasTelasDelDia(db, sucursal, fechaRD);
    final filas = [
      for (final v in ventas) ...await lineasVentaTelas(db, v['id'] as int),
    ];
    expect({
      'ventas del día': ventas.length,
      'total de la venta': sumaCentavos(ventas, 'total') / 100,
      'suma del total de las líneas': sumaCentavos(filas, 'total') / 100,
      'ganancias de la venta': sumaCentavos(ventas, 'ganancias') / 100,
      'suma de las ganancias de las líneas':
          sumaCentavos(filas, 'ganancias') / 100,
      'líneas': filas.length,
      'metros': sumaCentavos(filas, 'cantidad') / 100,
    }, {
      'ventas del día': 1,
      'total de la venta': total,
      'suma del total de las líneas': total,
      'ganancias de la venta': ganancias,
      'suma de las ganancias de las líneas': ganancias,
      'líneas': lineas,
      'metros': metrosVendidos,
    });
  }

  /// Lo que tiene que quedar después de vender el carrito de [carritoListo]
  /// una sola vez.
  Future<void> verificarVendidoUnaVez(int sucursal) => verificarVenta(sucursal,
      lineas: 1,
      metrosVendidos: metros,
      total: metros * precio,
      ganancias: metros * (precio - compra));

  group('registrar', () {
    test(
        'respuesta perdida en registrar_detalle_venta: la app ve un error y '
        'conserva el carrito, pero la línea ya quedó en la base', () async {
      final (sucursal, cubit) = await carritoListo();
      red().perderRespuesta(cuando: Cuando.rpc('registrar_detalle_venta'));

      expect(await cubit.onFormSubmit(), isFalse);

      expect(red().perdidas, ['rpc/registrar_detalle_venta']);
      expect(red().llegaron, isNot(contains('rpc/incrementar_venta')));
      expect(cubit.state.detVentas, hasLength(1));
      final ventas = await ventasTelasDelDia(celular.base, sucursal, fechaRD);
      final lineas =
          await lineasVentaTelas(celular.base, ventas.single['id'] as int);
      expect(numero(lineas.single['cantidad']), metros);
    });

    test(
        'respuesta perdida en registrar_detalle_venta y el usuario vuelve a '
        'tocar Guardar: la línea no se duplica y el total coincide con las '
        'líneas', () async {
      final (sucursal, cubit) = await carritoListo();
      red().perderRespuesta(cuando: Cuando.rpc('registrar_detalle_venta'));
      expect(await cubit.onFormSubmit(), isFalse);

      expect(await cubit.onFormSubmit(), isTrue);

      await verificarVendidoUnaVez(sucursal);
    },
        // bug: supabase/migrations/20261003000100_integridad_stock_y_ventas.sql:199 — registrar_detalle_venta no es idempotente: el reintento (lib/features/ventas/presentation/bloc/detalle_venta_form_cubit.dart:176 manda el mismo carrito sin id de operación) vuelve a sumar la línea (4 m / 100 Bs) mientras la venta suma una sola vez (50 Bs)
        skip: bugConocido);

    test(
        'sin conexión justo en incrementar_venta: el total de la venta '
        'coincide con la suma de sus líneas', () async {
      final (sucursal, cubit) = await carritoListo();
      red().cortar(cuando: Cuando.rpc('incrementar_venta'));

      expect(await cubit.onFormSubmit(), isFalse);

      expect(red().cortadas, ['rpc/incrementar_venta']);
      // Sin reintentar: lo que quedó en la base tiene que cerrar (todo o
      // nada).
      final ventas = await ventasTelasDelDia(celular.base, sucursal, fechaRD);
      final lineas = [
        for (final v in ventas)
          ...await lineasVentaTelas(celular.base, v['id'] as int),
      ];
      expect({
        'total de la venta': sumaCentavos(ventas, 'total') / 100,
        'ganancias de la venta': sumaCentavos(ventas, 'ganancias') / 100,
      }, {
        'total de la venta': sumaCentavos(lineas, 'total') / 100,
        'ganancias de la venta': sumaCentavos(lineas, 'ganancias') / 100,
      }, reason: 'la venta tiene que sumar lo mismo que sus líneas');
    },
        // bug: lib/features/ventas/presentation/bloc/detalle_venta_form_cubit.dart:180 — las líneas (registrar_detalle_venta) y el total (incrementar_venta) van en llamadas separadas: si la segunda falla, la línea de 50 Bs queda en la base y el total de la venta en 0
        skip: bugConocido);

    test(
        'sin conexión justo en incrementar_venta y el usuario vuelve a tocar '
        'Guardar: se vende una sola vez y el total coincide con las líneas',
        () async {
      final (sucursal, cubit) = await carritoListo();
      red().cortar(cuando: Cuando.rpc('incrementar_venta'), veces: 1);
      expect(await cubit.onFormSubmit(), isFalse);

      expect(await cubit.onFormSubmit(), isTrue);

      await verificarVendidoUnaVez(sucursal);
    },
        // bug: lib/features/ventas/presentation/bloc/detalle_venta_form_cubit.dart:176 — el reintento vuelve a mandar las líneas que ya se habían registrado: quedan 4 m / 100 Bs en las líneas y 50 Bs en la venta
        skip: bugConocido);

    test(
        'respuesta perdida en incrementar_venta y el usuario vuelve a tocar '
        'Guardar: la venta se cuenta una sola vez', () async {
      final (sucursal, cubit) = await carritoListo();
      red().perderRespuesta(cuando: Cuando.rpc('incrementar_venta'));
      expect(await cubit.onFormSubmit(), isFalse);

      expect(await cubit.onFormSubmit(), isTrue);

      await verificarVendidoUnaVez(sucursal);
    },
        // bug: supabase/migrations/20261003000100_integridad_stock_y_ventas.sql:210 — incrementar_venta y registrar_detalle_venta no son idempotentes: con la respuesta perdida todo ya se había aplicado y el reintento lo suma de nuevo (4 m, 100 Bs en las líneas y en la venta)
        skip: bugConocido);

    test(
        'sin conexión: falla limpia (no llega nada a la base), conserva el '
        'carrito y el reintento con señal vende una vez', () async {
      final (sucursal, cubit) = await carritoListo();
      red().cortar();

      // getVentaByFecha es un GET: postgrest lo reintenta 3 veces solo
      // (1 + 2 + 4 s) antes de dar el error.
      expect(await cubit.onFormSubmit(), isFalse);

      expect(red().llegaron, isEmpty);
      expect(cubit.state.detVentas, hasLength(1));
      expect(await ventasTelasDelDia(celular.base, sucursal, fechaRD), isEmpty);

      red().restablecer();
      expect(await cubit.onFormSubmit(), isTrue);
      await verificarVendidoUnaVez(sucursal);
    });

    test(
        'sin conexión al registrar las líneas: queda a lo sumo la venta del '
        'día vacía (cierra en 0) y el reintento la reusa', () async {
      final (sucursal, cubit) = await carritoListo();
      red().cortar(cuando: Cuando.rpc('registrar_detalle_venta'));

      expect(await cubit.onFormSubmit(), isFalse);

      expect(red().llegaron, ['ventas', 'ventas'],
          reason: 'buscó la venta del día y la creó');
      await verificarVenta(sucursal,
          lineas: 0, metrosVendidos: 0, total: 0, ganancias: 0);

      red().restablecer();
      expect(await cubit.onFormSubmit(), isTrue);
      await verificarVendidoUnaVez(sucursal);
    });
  });

  group('borrar una línea', () {
    const metrosB = 3;
    const precioB = 20;
    const compraB = 12;

    /// Venta del día con dos líneas (registrada con la red sana) y los blocs
    /// de la pantalla de detalle cargados. Devuelve la línea a borrar (la de
    /// la tela B).
    Future<(int, DetalleVentasBloc, int)> ventaConDosLineas() async {
      final sucursal = await datos.sucursal();
      final telaA = await datos.tela(precio: precio, compra: compra);
      final telaB = await datos.tela(precio: precioB, compra: compraB);
      final cubit = formulario(sucursal);
      await agregar(cubit, telaA);
      await agregar(cubit, telaB, cantidad: metrosB, precioVenta: precioB);
      expect(await cubit.onFormSubmit(), isTrue);

      final venta =
          (await ventasTelasDelDia(celular.base, sucursal, fechaRD)).single;
      final idventa = venta['id'] as int;
      final ventasRepo = VentasRepositoryImpl(VentasDatasourceImpl());
      final ventaBloc = VentaBloc(ventasRepository: ventasRepo, id: idventa);
      addTearDown(ventaBloc.close);
      final detalleBloc = DetalleVentasBloc(
        detalleVentasRepository:
            DetalleVentasRepositoryImpl(DetalleVentasDatasourceImpl()),
        updateVenta: ventaBloc.actualizarVenta,
        idventa: idventa,
      );
      addTearDown(detalleBloc.close);
      await ventaBloc.stream.firstWhere((s) => !s.isLoading);
      await detalleBloc.stream.firstWhere((s) => !s.isLoading);
      expect(detalleBloc.state.detalleVentas, hasLength(2));

      final lineaB = detalleBloc.state.detalleVentas
          .singleWhere((d) => d.idtelas == telaB)
          .id!;
      red().registro.clear();
      return (sucursal, detalleBloc, lineaB);
    }

    /// Lo que tiene que quedar después de borrar la línea B: solo la A.
    Future<void> verificarSoloLineaA(int sucursal) => verificarVenta(sucursal,
        lineas: 1,
        metrosVendidos: metros,
        total: metros * precio,
        ganancias: metros * (precio - compra));

    test(
        'sin conexión entre el borrado y incrementar_venta: el total de la '
        'venta coincide con las líneas que quedan', () async {
      final (sucursal, bloc, lineaB) = await ventaConDosLineas();
      red().cortar(cuando: Cuando.rpc('incrementar_venta'));

      expect(await bloc.deleteDetVenta(lineaB), isFalse);

      expect(red().llegaron, ['detalle_ventas', 'detalle_ventas'],
          reason: 'leyó la línea y la borró');
      expect(red().cortadas, ['rpc/incrementar_venta']);
      await verificarSoloLineaA(sucursal);
    },
        // bug: lib/features/ventas/presentation/bloc/detalle_ventas_bloc.dart:110 — el DELETE (detalleVentas_datasource_impl.dart:45) y el descuento del total (incrementar_venta) van en llamadas separadas: la línea de 60 Bs se borra y la venta sigue sumando 110 Bs con 50 Bs de líneas (y la pantalla ya sacó la línea: no hay cómo reintentar)
        skip: bugConocido);

    test(
        'respuesta perdida en el DELETE (aunque el usuario reintente): el '
        'total de la venta coincide con las líneas que quedan', () async {
      final (sucursal, bloc, lineaB) = await ventaConDosLineas();
      red().perderRespuesta(
          cuando: Cuando.tabla('detalle_ventas', metodo: 'DELETE'));

      expect(await bloc.deleteDetVenta(lineaB), isFalse);
      expect(red().perdidas, ['detalle_ventas']);

      // La pantalla sigue mostrando la línea: el usuario vuelve a borrarla.
      if (bloc.state.detalleVentas.any((d) => d.id == lineaB)) {
        await bloc.deleteDetVenta(lineaB);
      }
      await verificarSoloLineaA(sucursal);
    },
        // bug: lib/features/ventas/presentation/bloc/detalle_ventas_bloc.dart:104 — con la respuesta del DELETE perdida la línea ya no existe pero incrementar_venta nunca se llama; al reintentar, deleteDetalleVenta no la encuentra ("Detalle no encontrado") y la venta queda en 110 Bs con 50 Bs de líneas
        skip: bugConocido);

    test(
        'sin conexión: no borra nada, el total queda igual y el reintento con '
        'señal la borra y descuenta el total', () async {
      final (sucursal, bloc, lineaB) = await ventaConDosLineas();
      red().cortar();

      // El primer pedido es un GET (leer la línea): postgrest lo reintenta
      // 3 veces solo antes de dar el error.
      expect(await bloc.deleteDetVenta(lineaB), isFalse);

      expect(red().llegaron, isEmpty);
      expect(bloc.state.detalleVentas, hasLength(2));
      await verificarVenta(sucursal,
          lineas: 2,
          metrosVendidos: metros + metrosB,
          total: metros * precio + metrosB * precioB,
          ganancias:
              metros * (precio - compra) + metrosB * (precioB - compraB));

      red().restablecer();
      expect(await bloc.deleteDetVenta(lineaB), isTrue);
      await verificarSoloLineaA(sucursal);
    });
  });
}
