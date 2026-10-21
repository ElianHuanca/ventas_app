import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/detalle_venta_form_cubit.dart';

import '../../../../helpers/fake_repositories.dart';

/// Guarda las líneas recién cuando se completa [registro]: deja ver qué pasa
/// si se vuelve a tocar "Guardar" mientras tanto.
class _DetalleLento extends FakeDetalleVentasRepository {
  final registro = Completer<void>();

  @override
  Future<List<DetalleVenta>> createDetalleVenta(
      List<Map<String, dynamic>> detalleVentasLike, int idventas) async {
    await registro.future;
    return super.createDetalleVenta(detalleVentasLike, idventas);
  }
}

void main() {
  late FakeVentasRepository ventasRepo;
  late FakeDetalleVentasRepository detalleRepo;
  late DetalleVentaFormCubit cubit;

  setUp(() {
    ventasRepo = FakeVentasRepository();
    detalleRepo = FakeDetalleVentasRepository();
    cubit = DetalleVentaFormCubit(
      ventasRepository: ventasRepo,
      detalleVentasRepository: detalleRepo,
      idsucursal: 1,
    );
  });

  tearDown(() => cubit.close());

  void cargarLinea({
    int idtelas = 1,
    String cantidad = '2',
    String precio = '100',
    double precxcompra = 60,
  }) {
    cubit.onIdTelasChanged(idtelas);
    cubit.onNombreChanged('Lino');
    cubit.onCantidadChanged(cantidad);
    cubit.onPrecioChanged(precio);
    cubit.onPrecxCompraChanged(precxcompra);
  }

  group('addDetalleVenta', () {
    test('agrega una línea y acumula total y ganancias', () {
      cargarLinea(cantidad: '2', precio: '100', precxcompra: 60);
      cubit.addDetalleVenta();

      expect(cubit.state.detVentas.length, 1);
      final linea = cubit.state.detVentas.first;
      expect(linea['idtelas'], 1);
      expect(linea['cantidad'], 2.0);
      expect(linea['precio'], 100.0);
      expect(linea['total'], 200.0);
      // ganancia = (100 - 60) * 2 = 80
      expect(linea['ganancias'], 80.0);
      expect(cubit.state.total, 200.0);
      expect(cubit.state.ganancias, 80.0);
      // limpia cantidad y precio para la siguiente línea
      expect(cubit.state.cantidad, '');
      expect(cubit.state.precio, '');
    });

    test('mismo producto y precio hace merge sumando cantidad', () {
      cargarLinea(cantidad: '2', precio: '100', precxcompra: 60);
      cubit.addDetalleVenta();
      cargarLinea(cantidad: '3', precio: '100', precxcompra: 60);
      cubit.addDetalleVenta();

      expect(cubit.state.detVentas.length, 1);
      final linea = cubit.state.detVentas.first;
      expect(linea['cantidad'], 5.0);
      expect(linea['total'], 500.0);
      expect(linea['ganancias'], 200.0);
      expect(cubit.state.total, 500.0);
      expect(cubit.state.ganancias, 200.0);
    });

    test('mismo producto con distinto precio genera líneas separadas', () {
      cargarLinea(cantidad: '1', precio: '100');
      cubit.addDetalleVenta();
      cargarLinea(cantidad: '1', precio: '120');
      cubit.addDetalleVenta();

      expect(cubit.state.detVentas.length, 2);
      expect(cubit.state.total, 220.0);
    });

    test('ganancia es 0 cuando precxcompra es 0', () {
      cargarLinea(cantidad: '2', precio: '100', precxcompra: 0);
      cubit.addDetalleVenta();

      expect(cubit.state.detVentas.first['ganancias'], 0);
      expect(cubit.state.ganancias, 0);
      expect(cubit.state.total, 200.0);
    });

    test('redondea a 2 decimales', () {
      cargarLinea(cantidad: '3', precio: '33.33', precxcompra: 10.11);
      cubit.addDetalleVenta();

      final linea = cubit.state.detVentas.first;
      expect(linea['total'], 99.99);
      expect(linea['ganancias'], 69.66);
    });

    test('el total acumulado no arrastra error de coma flotante', () {
      cargarLinea(cantidad: '1', precio: '10.1', precxcompra: 5);
      cubit.addDetalleVenta();
      cargarLinea(idtelas: 2, cantidad: '1', precio: '20.2', precxcompra: 5);
      cubit.addDetalleVenta();

      // 10.1 + 20.2 en double da 30.299999999999997
      expect(cubit.state.total, 30.3);
      expect(cubit.state.ganancias, 20.3);

      cubit.removeDetalleVenta(2, 1.0, 20.2);
      expect(cubit.state.total, 10.1);
      expect(cubit.state.ganancias, 5.1);
    });

    // Casos mínimos de test/propiedades/carritos_propiedades_test.dart
    test('el merge sube el total lo que sube la línea, sin sumar redondeos',
        () {
      cargarLinea(cantidad: '0.5', precio: '0.01', precxcompra: 0);
      cubit.addDetalleVenta();
      cargarLinea(cantidad: '0.5', precio: '0.01', precxcompra: 0);
      cubit.addDetalleVenta();

      // 1 m × 0.01 = 0.01; cada 0.5 m redondeado por separado daba 0.02
      expect(cubit.state.detVentas.single['total'], 0.01);
      expect(cubit.state.total, 0.01);

      cubit.removeDetalleVenta(1, 1.0, 0.01);
      expect(cubit.state.total, 0);
    });

    test('la mitad del centavo redondea hacia arriba, como numeric', () {
      cargarLinea(cantidad: '3.75', precio: '23.22', precxcompra: 0);
      cubit.addDetalleVenta();

      // 3.75 × 23.22 = 87.075, en double 87.07499999999999 (daba 87.07)
      expect(cubit.state.detVentas.single['total'], 87.08);
      expect(cubit.state.total, 87.08);
    });

    test('sumar cantidades en el merge no deja ruido de coma flotante', () {
      cargarLinea(cantidad: '0.3', precio: '10');
      cubit.addDetalleVenta();
      cargarLinea(cantidad: '0.6', precio: '10');
      cubit.addDetalleVenta();

      // 0.3 + 0.6 en double da 0.8999999999999999
      expect(cubit.state.detVentas.single['cantidad'], 0.9);
    });

    test('NaN e Infinity no son cantidades ni precios válidos', () {
      for (final texto in ['NaN', 'Infinity', '-Infinity']) {
        cargarLinea(cantidad: texto, precio: '100');
        cubit.addDetalleVenta();
        cargarLinea(cantidad: '1', precio: texto);
        cubit.addDetalleVenta();
      }

      expect(cubit.state.detVentas, isEmpty);
      expect(cubit.state.total, 0);
    });

    test('no agrega sin producto seleccionado', () {
      cubit.onCantidadChanged('1');
      cubit.onPrecioChanged('100');
      cubit.addDetalleVenta();
      expect(cubit.state.detVentas, isEmpty);
    });

    test('no agrega con cantidad o precio inválidos', () {
      cargarLinea(cantidad: 'abc', precio: '100');
      cubit.addDetalleVenta();
      cargarLinea(cantidad: '1', precio: 'xyz');
      cubit.addDetalleVenta();
      cargarLinea(cantidad: '', precio: '100');
      cubit.addDetalleVenta();
      expect(cubit.state.detVentas, isEmpty);
    });

    test('no agrega con cantidad o precio menores o iguales a 0', () {
      cargarLinea(cantidad: '0', precio: '100');
      cubit.addDetalleVenta();
      cargarLinea(cantidad: '-1', precio: '100');
      cubit.addDetalleVenta();
      cargarLinea(cantidad: '1', precio: '0');
      cubit.addDetalleVenta();
      cargarLinea(cantidad: '1', precio: '-5');
      cubit.addDetalleVenta();
      expect(cubit.state.detVentas, isEmpty);
    });
  });

  group('removeDetalleVenta', () {
    test('quita la línea y resta total y ganancias', () {
      cargarLinea(cantidad: '2', precio: '100', precxcompra: 60);
      cubit.addDetalleVenta();
      cargarLinea(cantidad: '1', precio: '50', precxcompra: 20);
      cubit.onIdTelasChanged(2);
      cubit.addDetalleVenta();

      expect(cubit.state.detVentas.length, 2);
      expect(cubit.state.total, 250.0);
      expect(cubit.state.ganancias, 110.0);

      cubit.removeDetalleVenta(1, 2.0, 100.0);

      expect(cubit.state.detVentas.length, 1);
      expect(cubit.state.total, 50.0);
      expect(cubit.state.ganancias, 30.0);
    });

    test(
        'con líneas parecidas quita solo la que coincide en tela, cantidad y '
        'precio', () {
      // Tela 1, 2 x 100: la línea a quitar (queda última en la tabla)
      cargarLinea(idtelas: 1, cantidad: '2', precio: '100', precxcompra: 60);
      cubit.addDetalleVenta();
      // Misma tela a otro precio
      cargarLinea(idtelas: 1, cantidad: '1', precio: '120', precxcompra: 60);
      cubit.addDetalleVenta();
      // Otra tela al mismo precio
      cargarLinea(idtelas: 2, cantidad: '3', precio: '100', precxcompra: 60);
      cubit.addDetalleVenta();
      expect(cubit.state.total, 620.0);

      cubit.removeDetalleVenta(1, 2.0, 100.0);

      expect(
        cubit.state.detVentas
            .map((e) => [e['idtelas'], e['cantidad'], e['precio']]),
        [
          [2, 3.0, 100.0],
          [1, 1.0, 120.0],
        ],
      );
      expect(cubit.state.total, 420.0);
      // (100 - 60) * 3 + (120 - 60) * 1
      expect(cubit.state.ganancias, 180.0);
    });

    test('con datos inexistentes no modifica el estado', () {
      cargarLinea(cantidad: '2', precio: '100');
      cubit.addDetalleVenta();
      cubit.removeDetalleVenta(999, 1.0, 1.0);

      expect(cubit.state.detVentas.length, 1);
      expect(cubit.state.total, 200.0);
    });
  });

  group('onFormSubmit', () {
    test('un segundo envío mientras se guarda no registra la venta dos veces',
        () async {
      final lento = _DetalleLento();
      final cubitLento = DetalleVentaFormCubit(
        ventasRepository: ventasRepo,
        detalleVentasRepository: lento,
        idsucursal: 1,
      );
      addTearDown(cubitLento.close);
      cubitLento
        ..onIdTelasChanged(1)
        ..onNombreChanged('Lino')
        ..onCantidadChanged('2')
        ..onPrecioChanged('100')
        ..onPrecxCompraChanged(60)
        ..addDetalleVenta();

      final primero = cubitLento.onFormSubmit();
      try {
        await pumpEventQueue();
        expect(cubitLento.enviando, isTrue);
        // Doble toque en "Guardar": antes mandaba el carrito otra vez y la
        // base sumaba cantidades y total dos veces
        expect(await cubitLento.onFormSubmit(), isFalse);
      } finally {
        lento.registro.complete();
      }

      expect(await primero, isTrue);
      expect(lento.detallesCreados, hasLength(1));
      expect(ventasRepo.actualizaciones, hasLength(1));
      expect(cubitLento.enviando, isFalse);
    });

    test('sin items devuelve false y no toca los repositorios', () async {
      final ok = await cubit.onFormSubmit();

      expect(ok, false);
      expect(ventasRepo.createVentaCalls, 0);
      expect(detalleRepo.detallesCreados, isEmpty);
      expect(ventasRepo.actualizaciones, isEmpty);
    });

    test('descuento inválido devuelve false', () async {
      cargarLinea();
      cubit.addDetalleVenta();
      cubit.onDescuentoChanged('abc');

      final ok = await cubit.onFormSubmit();

      expect(ok, false);
      expect(detalleRepo.detallesCreados, isEmpty);
    });

    test('descuento NaN devuelve false sin escribir nada', () async {
      cargarLinea();
      cubit.addDetalleVenta();
      cubit.onDescuentoChanged('NaN');

      final ok = await cubit.onFormSubmit();

      expect(ok, false);
      expect(detalleRepo.detallesCreados, isEmpty);
      expect(ventasRepo.actualizaciones, isEmpty);
    });

    test(
        'flujo completo con venta inexistente: crea venta, detalles y actualiza',
        () async {
      ventasRepo.ventaByFecha = null; // no hay venta para la fecha
      cubit.onFechaChanged(DateTime(2024, 6, 10));
      cargarLinea(cantidad: '2', precio: '100', precxcompra: 60);
      cubit.addDetalleVenta();
      cubit.onDescuentoChanged('15');

      final ok = await cubit.onFormSubmit();

      expect(ok, true);
      expect(ventasRepo.createVentaCalls, 1);
      expect(detalleRepo.detallesCreados.length, 1);
      expect(detalleRepo.detallesCreados.first.length, 1);
      // la venta creada por el fake recibe id 10
      expect(detalleRepo.idsVentaUsados, [10]);
      expect(ventasRepo.idsActualizados, [10]);
      final update = ventasRepo.actualizaciones.single;
      expect(update['total'], 200.0);
      expect(update['ganancias'], 80.0);
      expect(update['descuento'], 15.0);
      expect(update['fecha'], DateTime(2024, 6, 10).toIso8601String());
    });

    test('con venta existente no crea una nueva', () async {
      ventasRepo.ventaByFecha = Venta(
        id: 42,
        fecha: DateTime(2024, 6, 10),
        total: 500,
        ganancias: 200,
        descuento: 0,
        idsucursales: 1,
      );
      cargarLinea(cantidad: '1', precio: '100', precxcompra: 60);
      cubit.addDetalleVenta();

      final ok = await cubit.onFormSubmit();

      expect(ok, true);
      expect(ventasRepo.createVentaCalls, 0);
      expect(detalleRepo.idsVentaUsados, [42]);
      expect(ventasRepo.idsActualizados, [42]);
    });

    test('descuento vacío se envía como 0', () async {
      cargarLinea();
      cubit.addDetalleVenta();

      final ok = await cubit.onFormSubmit();

      expect(ok, true);
      expect(ventasRepo.actualizaciones.single['descuento'], 0.0);
    });

    test('error del repositorio devuelve false', () async {
      cargarLinea();
      cubit.addDetalleVenta();
      ventasRepo.error = Exception('sin conexión');

      final ok = await cubit.onFormSubmit();

      expect(ok, false);
    });
  });
}
