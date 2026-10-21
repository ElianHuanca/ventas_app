@Timeout(Duration(minutes: 4))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/telas/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/ventas/infrastructure/infrastructure.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/bloc.dart';

import '../concurrencia/datos.dart';
import 'celular.dart';
import 'red_con_fallas.dart';

/// Venta de telas con la red cortándose. Registrar es UNA llamada
/// (`DetalleVentaFormCubit.onFormSubmit` → RPC `registrar_venta_telas`: la
/// venta del día, las líneas y los totales en una transacción) con la clave
/// de operación del envío: el reintento del mismo carrito lleva la misma y la
/// base no lo suma dos veces. Borrar una línea
/// (`DetalleVentasBloc.deleteDetVenta`) es otra (RPC `borrar_detalle_venta`:
/// borra y descuenta el total juntos; si la línea ya no está, no hace nada).
/// Antes eran 4 y 3 llamadas separadas y una falla en el medio las dejaba a
/// medias (bugs arreglados en la migración
/// `20261020000000_idempotencia_y_venta_telas.sql`). Mismos objetos que las
/// rutas `/det_venta/:idsucursal` y `/det_ventas/:idventa`, con la fecha
/// elegida en el formulario ([fechaRD], como "fecha anterior").
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
        'es una sola llamada (registrar_venta_telas): no quedan pasos '
        'intermedios que puedan fallar', () async {
      final (sucursal, cubit) = await carritoListo();

      expect(await cubit.onFormSubmit(), isTrue);

      expect(red().llegaron, ['rpc/registrar_venta_telas']);
      await verificarVendidoUnaVez(sucursal);
    });

    test(
        'respuesta perdida: la app ve un error y conserva el carrito, pero la '
        'venta ya quedó entera en la base (el total coincide con las líneas)',
        () async {
      final (sucursal, cubit) = await carritoListo();
      red().perderRespuesta(cuando: Cuando.rpc('registrar_venta_telas'));

      expect(await cubit.onFormSubmit(), isFalse);

      expect(red().perdidas, ['rpc/registrar_venta_telas']);
      expect(cubit.state.detVentas, hasLength(1),
          reason: 'el carrito queda para volver a tocar Guardar');
      // Sin reintentar: lo que quedó en la base cierra (todo o nada)
      await verificarVendidoUnaVez(sucursal);
    });

    test(
        'respuesta perdida y el usuario vuelve a tocar Guardar: la línea no se '
        'duplica y el total coincide con las líneas', () async {
      final (sucursal, cubit) = await carritoListo();
      red().perderRespuesta(cuando: Cuando.rpc('registrar_venta_telas'));
      expect(await cubit.onFormSubmit(), isFalse);

      // Volvió la señal: el mismo carrito, "Guardar" otra vez
      expect(await cubit.onFormSubmit(), isTrue);

      expect(red().llegaron,
          ['rpc/registrar_venta_telas', 'rpc/registrar_venta_telas']);
      await verificarVendidoUnaVez(sucursal);
    });

    test(
        'respuesta perdida dos veces seguidas y un tercer Guardar: se vende '
        'una sola vez', () async {
      final (sucursal, cubit) = await carritoListo();
      red().perderRespuesta(
          cuando: Cuando.rpc('registrar_venta_telas'), veces: 2);
      expect(await cubit.onFormSubmit(), isFalse);
      expect(await cubit.onFormSubmit(), isFalse);

      expect(await cubit.onFormSubmit(), isTrue);

      expect(red().perdidas, hasLength(2));
      await verificarVendidoUnaVez(sucursal);
    });

    test(
        'después del reintento que salió bien, otra venta el mismo día se suma '
        'aparte (la clave se renueva)', () async {
      final (sucursal, cubit) = await carritoListo();
      red().perderRespuesta(cuando: Cuando.rpc('registrar_venta_telas'));
      expect(await cubit.onFormSubmit(), isFalse);
      expect(await cubit.onFormSubmit(), isTrue);

      // La pantalla vuelve al listado y el usuario vende lo mismo de nuevo
      final otra = formulario(sucursal);
      await agregar(otra, cubit.state.detVentas.single['idtelas'] as int);
      expect(await otra.onFormSubmit(), isTrue);
      // El mismo carrito en el mismo formulario, después de un éxito, también
      // es otra venta (no un reintento)
      expect(await cubit.onFormSubmit(), isTrue);

      await verificarVenta(sucursal,
          lineas: 1,
          metrosVendidos: 3 * metros,
          total: 3 * metros * precio,
          ganancias: 3 * metros * (precio - compra));
    });

    test(
        'sin conexión: falla limpia (no llega nada a la base), conserva el '
        'carrito y el reintento con señal vende una vez', () async {
      final (sucursal, cubit) = await carritoListo();
      red().cortar();

      // Es un POST: postgrest no lo reintenta solo, falla enseguida
      expect(await cubit.onFormSubmit(), isFalse);

      expect(red().llegaron, isEmpty);
      expect(red().cortadas, ['rpc/registrar_venta_telas']);
      expect(cubit.state.detVentas, hasLength(1));
      expect(await ventasTelasDelDia(celular.base, sucursal, fechaRD), isEmpty);

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
    /// de la pantalla de detalle cargados, cableados como en app_router.
    /// Devuelve la línea a borrar (la de la tela B).
    Future<(int, VentaBloc, DetalleVentasBloc, int)> ventaConDosLineas() async {
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
        ventaActualizada: ventaBloc.mostrarVenta,
        idventa: idventa,
      );
      addTearDown(detalleBloc.close);
      // Si la carga ya terminó, el stream no repite el estado: esperar solo
      // si sigue cargando (con una base vacía, como en la CI, termina antes
      // de que el test se suscriba y firstWhere esperaba para siempre).
      const espera = Duration(seconds: 30);
      if (ventaBloc.state.isLoading) {
        await ventaBloc.stream.firstWhere((s) => !s.isLoading).timeout(espera);
      }
      if (detalleBloc.state.isLoading) {
        await detalleBloc.stream
            .firstWhere((s) => !s.isLoading)
            .timeout(espera);
      }
      expect(detalleBloc.state.detalleVentas, hasLength(2));

      final lineaB = detalleBloc.state.detalleVentas
          .singleWhere((d) => d.idtelas == telaB)
          .id!;
      red().registro.clear();
      return (sucursal, ventaBloc, detalleBloc, lineaB);
    }

    /// Lo que tiene que quedar después de borrar la línea B: solo la A.
    Future<void> verificarSoloLineaA(int sucursal) => verificarVenta(sucursal,
        lineas: 1,
        metrosVendidos: metros,
        total: metros * precio,
        ganancias: metros * (precio - compra));

    /// Espera a que la pantalla muestre la venta solo con la línea A (los
    /// blocs procesan sus eventos después de que deleteDetVenta devolvió).
    Future<void> pantallaSoloConLineaA(
        VentaBloc ventaBloc, DetalleVentasBloc bloc, int lineaB) async {
      const espera = Duration(seconds: 30);
      bool sinB(DetalleVentasState s) =>
          !s.detalleVentas.any((d) => d.id == lineaB);
      bool totalA(VentaState s) => s.venta?.total == metros * precio;
      if (!sinB(bloc.state)) {
        await bloc.stream.firstWhere(sinB).timeout(espera);
      }
      if (!totalA(ventaBloc.state)) {
        await ventaBloc.stream.firstWhere(totalA).timeout(espera);
      }
    }

    test(
        'es una sola llamada (borrar_detalle_venta): la pantalla muestra el '
        'total que dejó la base', () async {
      final (sucursal, ventaBloc, bloc, lineaB) = await ventaConDosLineas();

      expect(await bloc.deleteDetVenta(lineaB), isTrue);
      await pantallaSoloConLineaA(ventaBloc, bloc, lineaB);

      // La venta con el total descontado vino en la misma respuesta
      expect(red().llegaron, ['rpc/borrar_detalle_venta']);
      await verificarSoloLineaA(sucursal);
    });

    test(
        'respuesta perdida (sin reintentar): la línea y su total salieron '
        'juntos de la base, y la pantalla todavía la muestra para reintentar',
        () async {
      final (sucursal, _, bloc, lineaB) = await ventaConDosLineas();
      red().perderRespuesta(cuando: Cuando.rpc('borrar_detalle_venta'));

      expect(await bloc.deleteDetVenta(lineaB), isFalse);

      expect(red().perdidas, ['rpc/borrar_detalle_venta']);
      expect(bloc.state.detalleVentas.map((d) => d.id), contains(lineaB),
          reason: 'sale de la pantalla recién cuando la base respondió');
      await verificarSoloLineaA(sucursal);
    });

    test(
        'respuesta perdida y el usuario vuelve a borrarla: no descuenta dos '
        'veces, la línea sale de la pantalla y se ve el total de la base',
        () async {
      final (sucursal, ventaBloc, bloc, lineaB) = await ventaConDosLineas();
      red().perderRespuesta(cuando: Cuando.rpc('borrar_detalle_venta'));
      expect(await bloc.deleteDetVenta(lineaB), isFalse);

      // La pantalla sigue mostrando la línea: el usuario vuelve a borrarla
      expect(await bloc.deleteDetVenta(lineaB), isTrue);
      await pantallaSoloConLineaA(ventaBloc, bloc, lineaB);

      // La base ya no la tenía (devolvió null): la venta se volvió a leer
      expect(red().llegaron, [
        'rpc/borrar_detalle_venta',
        'rpc/borrar_detalle_venta',
        'ventas',
      ]);
      await verificarSoloLineaA(sucursal);
    });

    test(
        'sin conexión: no borra nada, el total queda igual y el reintento con '
        'señal la borra y descuenta el total', () async {
      final (sucursal, _, bloc, lineaB) = await ventaConDosLineas();
      red().cortar();

      // Es un POST: postgrest no lo reintenta solo, falla enseguida
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
