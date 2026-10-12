import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/produccion_form_cubit.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/venta_apliques_form_cubit.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/detalle_venta_form_cubit.dart';

import '../helpers/fake_repositories.dart';
import 'generadores.dart';

/// Los tres carritos (venta de telas, venta de apliques y fabricación) con
/// secuencias generadas de agregar/quitar líneas. Cada paso se compara
/// contra un modelo en enteros (centésimos), sin coma flotante.
void main() {
  group('venta de telas (DetalleVentaFormCubit)', () {
    propiedad(
        'cada paso deja una línea por tela+precio, con la cantidad '
        'sumada, y total/ganancias = suma de las líneas en centavos',
        _carrito(cantidad: any.decimal(1, 1001)), (carrito) {
      final prueba = _PruebaTelas(carrito);
      try {
        for (final paso in carrito.pasos) {
          prueba.aplicar(paso);
          prueba.verificar();
        }
      } finally {
        prueba.cerrar();
      }
    });

    propiedad('quitar todas las líneas vuelve a 0',
        _carritoConMezcla(cantidad: any.decimal(1, 1001)), (entrada) {
      final (carrito, mezcla) = entrada;
      final prueba = _PruebaTelas(carrito);
      try {
        carrito.agregados.forEach(prueba.aplicar);
        prueba.quitarTodo(mezcla);
        prueba.verificar();
        expect(prueba.cubit.state.detVentas, isEmpty);
        expect(prueba.cubit.state.total, 0);
        expect(prueba.cubit.state.ganancias, 0);
      } finally {
        prueba.cerrar();
      }
    });

    propiedad('el orden de agregado no cambia líneas ni totales',
        _carritoConMezcla(cantidad: any.decimal(1, 1001)), (entrada) {
      final (carrito, mezcla) = entrada;
      final enOrden = _PruebaTelas(carrito);
      final mezclado = _PruebaTelas(carrito);
      try {
        carrito.agregados.forEach(enOrden.aplicar);
        carrito.agregados.mezclados(mezcla).forEach(mezclado.aplicar);
        expect(mezclado.foto(), enOrden.foto());
      } finally {
        enOrden.cerrar();
        mezclado.cerrar();
      }
    });

    propiedad(
        'lo que se envía a la base cuadra: la suma de las líneas es '
        'el total y las ganancias de la venta',
        _carrito(cantidad: any.decimal(1, 1001)), (carrito) async {
      final prueba = _PruebaTelas(carrito);
      try {
        carrito.pasos.forEach(prueba.aplicar);
        final lineas = prueba.cubit.state.detVentas;
        if (lineas.isEmpty) return;

        expect(await prueba.cubit.onFormSubmit(), isTrue);

        final enviadas = prueba.detalles.detallesCreados.single;
        final venta = prueba.ventas.actualizaciones.single;
        expect(_sumaCentavos(enviadas, 'total'), centavos(venta['total']));
        expect(
            _sumaCentavos(enviadas, 'ganancias'), centavos(venta['ganancias']));
      } finally {
        prueba.cerrar();
      }
    });

    propiedad(
        'el total de cada línea es cantidad × precio redondeado a centavos '
        '(mitad hacia arriba, como numeric en Postgres)',
        _carrito(cantidad: any.decimal(1, 1001)), (carrito) {
      final prueba = _PruebaTelas(carrito);
      try {
        carrito.pasos.forEach(prueba.aplicar);
        for (final linea in prueba.cubit.state.detVentas) {
          final cantidad = centavos(linea['cantidad']);
          final precio = centavos(linea['precio']);
          expect(centavos(linea['total']),
              diezmilesimosACentavos(cantidad * precio),
              reason: '$cantidad centésimos × $precio centavos');
        }
      } finally {
        prueba.cerrar();
      }
    });
  });

  group('venta de apliques (VentaApliquesFormCubit)', () {
    propiedad(
        'cada paso respeta el stock por aplique+color, deja una línea '
        'por aplique+color+precio y total/ganancias = suma de las líneas',
        _carrito(cantidad: any.unidades(1, 6)), (carrito) {
      final prueba = _PruebaApliques(carrito);
      try {
        for (final paso in carrito.pasos) {
          prueba.aplicar(paso);
          prueba.verificar();
        }
      } finally {
        prueba.cerrar();
      }
    });

    propiedad('quitar todas las líneas vuelve a 0',
        _carritoConMezcla(cantidad: any.unidades(1, 6)), (entrada) {
      final (carrito, mezcla) = entrada;
      final prueba = _PruebaApliques(carrito);
      try {
        carrito.agregados.forEach(prueba.aplicar);
        prueba.quitarTodo(mezcla);
        prueba.verificar();
        expect(prueba.cubit.state.detalles, isEmpty);
        expect(prueba.cubit.state.total, 0);
        expect(prueba.cubit.state.ganancias, 0);
      } finally {
        prueba.cerrar();
      }
    });

    propiedad(
        'con stock de sobra, el orden de agregado no cambia líneas ni totales',
        _carritoConMezcla(cantidad: any.unidades(1, 6)), (entrada) {
      final (carrito, mezcla) = entrada;
      final conStock = carrito.conStockDeSobra();
      final enOrden = _PruebaApliques(conStock);
      final mezclado = _PruebaApliques(conStock);
      try {
        conStock.agregados.forEach(enOrden.aplicar);
        conStock.agregados.mezclados(mezcla).forEach(mezclado.aplicar);
        expect(mezclado.foto(), enOrden.foto());
      } finally {
        enOrden.cerrar();
        mezclado.cerrar();
      }
    });

    propiedad(
        'lo que se envía a la base cuadra: total = suma de las líneas '
        'menos el descuento',
        _carrito(cantidad: any.unidades(1, 6)), (carrito) async {
      final repo = FakeVentasApliquesRepository();
      final prueba = _PruebaApliques(carrito, repo: repo);
      try {
        carrito.pasos.forEach(prueba.aplicar);
        final lineas = prueba.cubit.state.detalles;
        if (lineas.isEmpty) return;
        // Un descuento de hasta el total
        final descuento = Decimal(
            _sumaCentavos(lineas, 'total') * carrito.descuentoPorMil ~/ 1000);
        prueba.cubit.onDescuentoChanged(descuento.texto);

        expect(await prueba.cubit.onFormSubmit(), isTrue);

        expect(repo.lastTotal, esMontoEnCentavos);
        expect(centavos(repo.lastTotal!),
            _sumaCentavos(repo.lastDetalles!, 'total') - descuento.centesimos);
        expect(centavos(repo.lastGanancias!),
            _sumaCentavos(repo.lastDetalles!, 'ganancias'));
      } finally {
        prueba.cerrar();
      }
    });

    propiedad(
        'el total de cada línea es cantidad × precio redondeado a centavos '
        '(mitad hacia arriba, como numeric en Postgres)',
        _carrito(cantidad: any.unidades(1, 6)), (carrito) {
      final prueba = _PruebaApliques(carrito);
      try {
        carrito.pasos.forEach(prueba.aplicar);
        for (final linea in prueba.cubit.state.detalles) {
          final cantidad = centavos(linea['cantidad']);
          final precio = centavos(linea['precio']);
          expect(centavos(linea['total']),
              diezmilesimosACentavos(cantidad * precio),
              reason: '$cantidad centésimos × $precio centavos');
        }
      } finally {
        prueba.cerrar();
      }
    });
  });

  group('fabricación (ProduccionFormCubit)', () {
    propiedad(
        'cada paso deja una línea por aplique+color con la cantidad '
        'sumada',
        _carrito(cantidad: any.unidades(1, 20)), (carrito) async {
      final prueba = _PruebaProduccion(carrito);
      try {
        for (final paso in carrito.pasos) {
          await prueba.aplicar(paso);
          prueba.verificar();
        }
      } finally {
        await prueba.cerrar();
      }
    });

    propiedad('quitar todas las líneas deja el listado vacío',
        _carritoConMezcla(cantidad: any.unidades(1, 20)), (entrada) async {
      final (carrito, mezcla) = entrada;
      final prueba = _PruebaProduccion(carrito);
      try {
        for (final paso in carrito.agregados) {
          await prueba.aplicar(paso);
        }
        prueba.quitarTodo(mezcla);
        expect(prueba.cubit.state.detProducciones, isEmpty);
      } finally {
        await prueba.cerrar();
      }
    });

    propiedad('el orden de agregado no cambia las líneas',
        _carritoConMezcla(cantidad: any.unidades(1, 20)), (entrada) async {
      final (carrito, mezcla) = entrada;
      final enOrden = _PruebaProduccion(carrito);
      final mezclado = _PruebaProduccion(carrito);
      try {
        for (final paso in carrito.agregados) {
          await enOrden.aplicar(paso);
        }
        for (final paso in carrito.agregados.mezclados(mezcla)) {
          await mezclado.aplicar(paso);
        }
        expect(mezclado.foto(), enOrden.foto());
      } finally {
        await enOrden.cerrar();
        await mezclado.cerrar();
      }
    });

    propiedad('lo que se registra son exactamente las líneas del listado',
        _carrito(cantidad: any.unidades(1, 20)), (carrito) async {
      final prueba = _PruebaProduccion(carrito);
      try {
        for (final paso in carrito.pasos) {
          await prueba.aplicar(paso);
        }
        if (prueba.modelo.isEmpty) return;

        expect(await prueba.cubit.onFormSubmit(), isNull);

        final lineas = prueba.repo.produccionesCreadas.single['lineas']
            as List<Map<String, dynamic>>;
        expect({
          for (final l in lineas)
            (l['idaplique'] as int, l['idcolor'] as int):
                centavos(l['cantidad'])
        }, prueba.modelo);
        expect(prueba.cubit.state.detProducciones, isEmpty);
      } finally {
        await prueba.cerrar();
      }
    });
  });
}

// --- Entradas -------------------------------------------------------------

const _productos = 3;
const _colores = 2;
const _precios = 3;

/// Textos que el carrito tiene que ignorar como cantidad o precio.
const _textosInvalidos = [
  '',
  ' ',
  'abc',
  '0',
  '-1',
  '-0.5',
  '0.00',
  '1,5',
  '.',
  'NaN',
  'Infinity',
  '-Infinity',
];

sealed class _Paso {}

class _Agregar extends _Paso {
  _Agregar(this.producto, this.color, this.precio, this.cantidad);

  final int producto;
  final int color;

  /// Índice en la paleta de precios del carrito.
  final int precio;
  final Decimal cantidad;

  @override
  String toString() => 'agregar(p$producto c$color \$$precio × $cantidad)';
}

class _Quitar extends _Paso {
  _Quitar(this.linea);

  /// Índice (módulo la cantidad de líneas) de la línea a quitar.
  final int linea;

  @override
  String toString() => 'quitar(#$linea)';
}

class _Invalido extends _Paso {
  _Invalido(this.producto, this.color, this.texto, {required this.enPrecio});

  final int producto;
  final int color;
  final String texto;

  /// El texto inválido va en el precio (si no, en la cantidad).
  final bool enPrecio;

  @override
  String toString() =>
      'inválido(p$producto c$color ${enPrecio ? 'precio' : 'cantidad'}: '
      '"$texto")';
}

class _Carrito {
  _Carrito(
      this.costos, this.precios, this.stock, this.pasos, this.descuentoPorMil);

  /// Por producto: precio de compra (telas) o costo de fabricación
  /// (apliques). 0 = sin cargar.
  final List<Decimal> costos;

  /// Paleta chica de precios: repetirlos fuerza el merge de líneas.
  final List<Decimal> precios;

  /// Stock por [producto][color] (solo apliques).
  final List<List<Decimal>> stock;
  final List<_Paso> pasos;

  /// Descuento al cobrar, en milésimos del total (0 a 1000).
  final int descuentoPorMil;

  Iterable<_Agregar> get agregados => pasos.whereType<_Agregar>();

  /// El mismo carrito con stock para todo lo que se agrega.
  _Carrito conStockDeSobra() {
    final necesario = [
      for (var p = 0; p < _productos; p++) List.filled(_colores, 0)
    ];
    for (final a in agregados) {
      necesario[a.producto][a.color] += a.cantidad.centesimos;
    }
    return _Carrito(
        costos,
        precios,
        [
          for (final porColor in necesario)
            [for (final c in porColor) Decimal(c)]
        ],
        pasos,
        descuentoPorMil);
  }

  @override
  String toString() => 'costos: $costos, precios: $precios, stock: $stock, '
      'pasos: $pasos, descuento: $descuentoPorMil‰';
}

Generator<_Paso> _paso(Generator<Decimal> cantidad) => any.combine6(
      // 0-6 agregar, 7-8 quitar, 9-10 inválido
      any.entero(0, 11),
      any.entero(0, _productos),
      any.entero(0, _colores),
      any.entero(0, _precios),
      any.entero(0, _textosInvalidos.length),
      cantidad,
      (int tipo, int producto, int color, int precio, int invalido,
          Decimal cant) {
        if (tipo <= 6) return _Agregar(producto, color, precio, cant);
        if (tipo <= 8) return _Quitar(invalido);
        return _Invalido(producto, color, _textosInvalidos[invalido],
            enPrecio: tipo == 10);
      },
    );

Generator<_Carrito> _carrito({required Generator<Decimal> cantidad}) =>
    any.combine5(
      any.listWithLength(_productos, any.montoOCero(5000)),
      any.listWithLength(_precios, any.decimal(1, 20000)),
      any.listWithLength(
          _productos, any.listWithLength(_colores, any.unidades(0, 12))),
      any.listWithLengthInRange(0, 25, _paso(cantidad)),
      any.entero(0, 1001),
      _Carrito.new,
    );

/// Un carrito y una semilla para mezclar el orden de sus pasos.
Generator<(_Carrito, int)> _carritoConMezcla(
        {required Generator<Decimal> cantidad}) =>
    any.combine2(_carrito(cantidad: cantidad), any.entero(0, 1 << 30),
        (_Carrito c, int m) => (c, m));

extension _Mezclar<T> on Iterable<T> {
  List<T> mezclados(int semilla) => toList()..shuffle(Random(semilla));
}

int _sumaCentavos(List<Map<String, dynamic>> lineas, String campo) =>
    lineas.fold(0, (suma, l) => suma + centavos(l[campo] as num));

/// Comunes a los dos carritos de venta: cada línea y los totales en
/// centavos exactos, y el total/ganancias = suma de las líneas.
void _verificarTotales(
    List<Map<String, dynamic>> lineas, double total, double ganancias) {
  for (final l in lineas) {
    expect(l['total'], esMontoEnCentavos, reason: 'total de la línea $l');
    expect(l['ganancias'], esMontoEnCentavos,
        reason: 'ganancias de la línea $l');
  }
  expect(total, esMontoEnCentavos, reason: 'total del carrito');
  expect(ganancias, esMontoEnCentavos, reason: 'ganancias del carrito');
  expect(centavos(total), _sumaCentavos(lineas, 'total'),
      reason: 'total = suma de las líneas');
  expect(centavos(ganancias), _sumaCentavos(lineas, 'ganancias'),
      reason: 'ganancias = suma de las líneas');
}

// --- Venta de telas ---------------------------------------------------------

class _PruebaTelas {
  _PruebaTelas(this.carrito)
      : cubit = DetalleVentaFormCubit(
          ventasRepository: FakeVentasRepository(),
          detalleVentasRepository: FakeDetalleVentasRepository(),
          idsucursal: 1,
        );

  final _Carrito carrito;
  final DetalleVentaFormCubit cubit;
  FakeVentasRepository get ventas =>
      cubit.ventasRepository as FakeVentasRepository;
  FakeDetalleVentasRepository get detalles =>
      cubit.detalleVentasRepository as FakeDetalleVentasRepository;

  /// (idtelas, precio en centavos) → cantidad en centésimos.
  final modelo = <(int, int), int>{};

  void _cargar(int producto, String cantidad, String precio) {
    cubit
      ..onIdTelasChanged(producto + 1)
      ..onNombreChanged('Tela $producto')
      ..onPrecxCompraChanged(carrito.costos[producto].valor)
      ..onCantidadChanged(cantidad)
      ..onPrecioChanged(precio);
  }

  void aplicar(_Paso paso) {
    switch (paso) {
      case _Agregar(:final producto, :final precio, :final cantidad):
        final p = carrito.precios[precio];
        _cargar(producto, cantidad.texto, p.texto);
        cubit.addDetalleVenta();
        modelo.update((producto + 1, p.centesimos),
            (actual) => actual + cantidad.centesimos,
            ifAbsent: () => cantidad.centesimos);
      case _Quitar(:final linea):
        final lineas = cubit.state.detVentas;
        if (lineas.isEmpty) return;
        _quitar(lineas[linea % lineas.length]);
      case _Invalido(:final producto, :final texto, :final enPrecio):
        final antes = foto();
        _cargar(producto, enPrecio ? '1' : texto, enPrecio ? texto : '1');
        cubit.addDetalleVenta();
        expect(foto(), antes, reason: 'un dato inválido no cambia el carrito');
    }
  }

  void _quitar(Map<String, dynamic> linea) {
    cubit.removeDetalleVenta(
      linea['idtelas'] as int,
      (linea['cantidad'] as num).toDouble(),
      (linea['precio'] as num).toDouble(),
    );
    modelo.remove((linea['idtelas'] as int, centavos(linea['precio'])));
  }

  void quitarTodo(int mezcla) {
    for (final linea in cubit.state.detVentas.mezclados(mezcla)) {
      _quitar(linea);
    }
  }

  void verificar() {
    final state = cubit.state;
    expect(state.detVentas.length, modelo.length,
        reason: 'una línea por tela+precio');
    for (final l in state.detVentas) {
      final clave = (l['idtelas'] as int, centavos(l['precio']));
      expect(modelo, contains(clave), reason: 'línea inesperada $l');
      expect(l['cantidad'], modelo[clave]! / 100,
          reason: 'cantidad = suma de lo agregado, sin ruido: $l');
    }
    _verificarTotales(state.detVentas, state.total, state.ganancias);
  }

  /// Líneas (sin importar el orden) y totales.
  Map<Object, Object> foto() => {
        for (final l in cubit.state.detVentas)
          (l['idtelas'], l['precio']): (
            l['cantidad'],
            l['total'],
            l['ganancias']
          ),
        'total': cubit.state.total,
        'ganancias': cubit.state.ganancias,
      };

  void cerrar() => cubit.close();
}

// --- Venta de apliques ------------------------------------------------------

class _PruebaApliques {
  _PruebaApliques(this.carrito, {FakeVentasApliquesRepository? repo})
      : cubit = VentaApliquesFormCubit(
          ventasApliquesRepository: repo ?? FakeVentasApliquesRepository(),
          idsucursal: 1,
        );

  final _Carrito carrito;
  final VentaApliquesFormCubit cubit;

  /// (idapliques, idcolor, precio en centavos) → cantidad en centésimos.
  final modelo = <(int, int, int), int>{};

  int _enCarrito(int idapliques, int idcolor) => modelo.entries
      .where((e) => e.key.$1 == idapliques && e.key.$2 == idcolor)
      .fold(0, (suma, e) => suma + e.value);

  String? _cargarYAgregar(
      int producto, int color, String cantidad, String precio) {
    cubit
      ..onApliqueChanged(Aplique(
        id: producto + 1,
        nombre: 'Aplique $producto',
        costoFabricacion: carrito.costos[producto].valor,
      ))
      ..onColorChanged(StockAplique(
        apliqueId: producto + 1,
        colorId: color + 1,
        colorNombre: 'Color $color',
        hex: '000000',
        stock: carrito.stock[producto][color].valor,
      ))
      ..onCantidadChanged(cantidad)
      ..onPrecioChanged(precio);
    return cubit.addDetalle();
  }

  void aplicar(_Paso paso) {
    switch (paso) {
      case _Agregar(
          :final producto,
          :final color,
          :final precio,
          :final cantidad
        ):
        final p = carrito.precios[precio];
        final stock = carrito.stock[producto][color].centesimos;
        final entra =
            _enCarrito(producto + 1, color + 1) + cantidad.centesimos <= stock;
        final antes = foto();

        final error = _cargarYAgregar(producto, color, cantidad.texto, p.texto);

        if (entra) {
          expect(error, isNull,
              reason: 'hay stock ($stock centésimos) para $cantidad más');
          modelo.update((producto + 1, color + 1, p.centesimos),
              (actual) => actual + cantidad.centesimos,
              ifAbsent: () => cantidad.centesimos);
        } else {
          expect(error, startsWith('Stock insuficiente'));
          expect(foto(), antes, reason: 'sin stock no cambia el carrito');
        }
      case _Quitar(:final linea):
        final lineas = cubit.state.detalles;
        if (lineas.isEmpty) return;
        _quitar(lineas[linea % lineas.length]);
      case _Invalido(
          :final producto,
          :final color,
          :final texto,
          :final enPrecio
        ):
        final antes = foto();
        final error = _cargarYAgregar(
            producto, color, enPrecio ? '1' : texto, enPrecio ? texto : '1');
        expect(error, isNotNull, reason: 'dato inválido "$texto"');
        expect(foto(), antes, reason: 'un dato inválido no cambia el carrito');
    }
  }

  void _quitar(Map<String, dynamic> linea) {
    cubit.removeDetalle(
      linea['idapliques'] as int,
      linea['idcolor'] as int,
      (linea['cantidad'] as num).toDouble(),
      (linea['precio'] as num).toDouble(),
    );
    modelo.remove((
      linea['idapliques'] as int,
      linea['idcolor'] as int,
      centavos(linea['precio'])
    ));
  }

  void quitarTodo(int mezcla) {
    for (final linea in cubit.state.detalles.mezclados(mezcla)) {
      _quitar(linea);
    }
  }

  void verificar() {
    final state = cubit.state;
    expect(state.detalles.length, modelo.length,
        reason: 'una línea por aplique+color+precio');
    for (final l in state.detalles) {
      final clave =
          (l['idapliques'] as int, l['idcolor'] as int, centavos(l['precio']));
      expect(modelo, contains(clave), reason: 'línea inesperada $l');
      expect(l['cantidad'], modelo[clave]! / 100,
          reason: 'cantidad = suma de lo agregado, sin ruido: $l');
    }
    // Nunca más de lo que hay en stock por aplique+color
    for (var p = 0; p < _productos; p++) {
      for (var c = 0; c < _colores; c++) {
        final enCarrito = state.detalles
            .where((l) => l['idapliques'] == p + 1 && l['idcolor'] == c + 1)
            .fold(0, (suma, l) => suma + centavos(l['cantidad']));
        expect(enCarrito, lessThanOrEqualTo(carrito.stock[p][c].centesimos),
            reason: 'stock del aplique ${p + 1} color ${c + 1}');
      }
    }
    _verificarTotales(state.detalles, state.total, state.ganancias);
  }

  Map<Object, Object> foto() => {
        for (final l in cubit.state.detalles)
          (l['idapliques'], l['idcolor'], l['precio']): (
            l['cantidad'],
            l['total'],
            l['ganancias']
          ),
        'total': cubit.state.total,
        'ganancias': cubit.state.ganancias,
      };

  void cerrar() => cubit.close();
}

// --- Fabricación ------------------------------------------------------------

class _PruebaProduccion {
  _PruebaProduccion(this.carrito)
      : repo = FakeApliquesRepository(colores: [
          for (var c = 0; c < _colores; c++)
            ColorItem(id: c + 1, nombre: 'Color $c', vinculado: true)
        ]) {
    cubit = ProduccionFormCubit(apliquesRepository: repo, idsucursal: 1);
  }

  final _Carrito carrito;
  final FakeApliquesRepository repo;
  late final ProduccionFormCubit cubit;

  /// (idaplique, idcolor) → cantidad en centésimos.
  final modelo = <(int, int), int>{};

  Future<String?> _cargarYAgregar(
      int producto, int color, String cantidad) async {
    await cubit.onApliqueChanged(
        Aplique(id: producto + 1, nombre: 'Aplique $producto'));
    cubit
      ..onColorChanged(
          ColorItem(id: color + 1, nombre: 'Color $color', hex: '000000'))
      ..onCantidadChanged(cantidad);
    return cubit.addDetalleProduccion();
  }

  Future<void> aplicar(_Paso paso) async {
    switch (paso) {
      case _Agregar(:final producto, :final color, :final cantidad):
        final error = await _cargarYAgregar(producto, color, cantidad.texto);
        expect(error, isNull);
        modelo.update(
            (producto + 1, color + 1), (actual) => actual + cantidad.centesimos,
            ifAbsent: () => cantidad.centesimos);
      case _Quitar(:final linea):
        final lineas = cubit.state.detProducciones;
        if (lineas.isEmpty) return;
        _quitar(lineas[linea % lineas.length]);
      case _Invalido(:final producto, :final color, :final texto):
        final antes = foto();
        final error = await _cargarYAgregar(producto, color, texto);
        expect(error, isNotNull, reason: 'cantidad inválida "$texto"');
        expect(foto(), antes, reason: 'un dato inválido no cambia el listado');
    }
  }

  void _quitar(Map<String, dynamic> linea) {
    cubit.removeDetalleProduccion(
      linea['idaplique'] as int,
      linea['idcolor'] as int,
      (linea['cantidad'] as num).toDouble(),
    );
    modelo.remove((linea['idaplique'] as int, linea['idcolor'] as int));
  }

  void quitarTodo(int mezcla) {
    for (final linea in cubit.state.detProducciones.mezclados(mezcla)) {
      _quitar(linea);
    }
  }

  void verificar() {
    final lineas = cubit.state.detProducciones;
    expect(lineas.length, modelo.length, reason: 'una línea por aplique+color');
    for (final l in lineas) {
      final clave = (l['idaplique'] as int, l['idcolor'] as int);
      expect(modelo, contains(clave), reason: 'línea inesperada $l');
      expect(l['cantidad'], modelo[clave]! / 100,
          reason: 'cantidad = suma de lo agregado, sin ruido: $l');
    }
  }

  Map<Object, Object> foto() => {
        for (final l in cubit.state.detProducciones)
          (l['idaplique'], l['idcolor']): l['cantidad'],
      };

  Future<void> cerrar() async {
    // load() del constructor puede seguir en vuelo
    await pumpEventQueue();
    await cubit.close();
  }
}
