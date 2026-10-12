import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/venta_apliques_form_cubit.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeVentasApliquesRepository repo;
  late VentaApliquesFormCubit cubit;

  final aplique = Aplique(id: 1, nombre: 'Flor', costoFabricacion: 10);
  const stockRojo = StockAplique(
    apliqueId: 1,
    colorId: 5,
    colorNombre: 'Rojo',
    hex: '#FF0000',
    stock: 10,
  );

  setUp(() {
    repo = FakeVentasApliquesRepository();
    cubit = VentaApliquesFormCubit(
      ventasApliquesRepository: repo,
      idsucursal: 3,
    );
  });

  tearDown(() => cubit.close());

  void seleccionar({double stock = 10}) {
    cubit.onApliqueChanged(aplique);
    cubit.onColorChanged(StockAplique(
      apliqueId: 1,
      colorId: 5,
      colorNombre: 'Rojo',
      hex: '#FF0000',
      stock: stock,
    ));
  }

  group('validaciones de addDetalle', () {
    test('sin aplique devuelve mensaje de error', () {
      expect(cubit.addDetalle(), 'Seleccione un aplique');
    });

    test('sin color devuelve mensaje de error', () {
      cubit.onApliqueChanged(aplique);
      expect(cubit.addDetalle(), 'Seleccione un color');
    });

    test('cantidad inválida devuelve mensaje de error', () {
      seleccionar();
      cubit.onCantidadChanged('abc');
      expect(cubit.addDetalle(), 'Ingrese una cantidad válida');
    });

    test('precio inválido devuelve mensaje de error', () {
      seleccionar();
      cubit.onCantidadChanged('1');
      expect(cubit.addDetalle(), 'Ingrese un precio válido');
    });

    test('cantidad o precio menores o iguales a 0 devuelven error', () {
      seleccionar();
      cubit.onCantidadChanged('0');
      cubit.onPrecioChanged('100');
      expect(cubit.addDetalle(), 'La cantidad debe ser mayor a 0');
      cubit.onCantidadChanged('-1');
      expect(cubit.addDetalle(), 'La cantidad debe ser mayor a 0');
      cubit.onCantidadChanged('1');
      cubit.onPrecioChanged('-1');
      expect(cubit.addDetalle(), 'El precio debe ser mayor a 0');
      cubit.onPrecioChanged('0');
      expect(cubit.addDetalle(), 'El precio debe ser mayor a 0');
      expect(cubit.state.detalles, isEmpty);
    });
  });

  group('addDetalle válido', () {
    test('agrega línea con nombre compuesto, total y ganancia por costo', () {
      seleccionar();
      cubit.onCantidadChanged('2');
      cubit.onPrecioChanged('25');

      final error = cubit.addDetalle();

      expect(error, isNull);
      final linea = cubit.state.detalles.single;
      expect(linea['idapliques'], 1);
      expect(linea['idcolor'], 5);
      expect(linea['nombre'], 'Flor (Rojo)');
      expect(linea['cantidad'], 2.0);
      expect(linea['total'], 50.0);
      // ganancia = (25 - 10) * 2 = 30
      expect(linea['ganancias'], 30.0);
      expect(cubit.state.total, 50.0);
      expect(cubit.state.ganancias, 30.0);
    });

    test('merge por aplique+color+precio suma cantidad', () {
      seleccionar();
      cubit.onCantidadChanged('2');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();
      cubit.onCantidadChanged('3');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();

      expect(cubit.state.detalles.length, 1);
      final linea = cubit.state.detalles.single;
      expect(linea['cantidad'], 5.0);
      expect(linea['total'], 125.0);
      expect(linea['ganancias'], 75.0);
      expect(cubit.state.total, 125.0);
    });

    test('mismo aplique+color con distinto precio son líneas separadas', () {
      seleccionar();
      cubit.onCantidadChanged('1');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();
      cubit.onCantidadChanged('1');
      cubit.onPrecioChanged('30');
      cubit.addDetalle();

      expect(cubit.state.detalles.length, 2);
    });
  });

  group('bloqueo de sobre-stock', () {
    test('cantidad mayor al stock disponible se rechaza', () {
      seleccionar(stock: 5);
      cubit.onCantidadChanged('6');
      cubit.onPrecioChanged('25');

      expect(cubit.addDetalle(), contains('Stock insuficiente'));
      expect(cubit.state.detalles, isEmpty);
    });

    test('considera lo ya acumulado en el carrito', () {
      seleccionar(stock: 10);
      cubit.onCantidadChanged('6');
      cubit.onPrecioChanged('25');
      expect(cubit.addDetalle(), isNull);

      // 6 en carrito + 5 nuevos = 11 > 10
      cubit.onCantidadChanged('5');
      cubit.onPrecioChanged('30');
      expect(cubit.addDetalle(), contains('Stock insuficiente'));

      // hasta el límite exacto sí pasa
      cubit.onCantidadChanged('4');
      expect(cubit.addDetalle(), isNull);
      expect(cubit.state.detalles.length, 2);
    });

    test('el acumulado es por aplique+color, otro color no lo bloquea', () {
      seleccionar(stock: 10);
      cubit.onCantidadChanged('8');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();

      cubit.onColorChanged(const StockAplique(
        apliqueId: 1,
        colorId: 6,
        colorNombre: 'Azul',
        hex: '#0000FF',
        stock: 3,
      ));
      cubit.onCantidadChanged('3');
      cubit.onPrecioChanged('25');

      expect(cubit.addDetalle(), isNull);
      expect(cubit.state.detalles.length, 2);
    });
  });

  group('removeDetalle', () {
    test('quita la línea y resta totales', () {
      seleccionar();
      cubit.onCantidadChanged('2');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();

      cubit.removeDetalle(1, 5, 2.0, 25.0);

      expect(cubit.state.detalles, isEmpty);
      expect(cubit.state.total, 0);
      expect(cubit.state.ganancias, 0);
    });

    test(
        'con líneas parecidas quita solo la que coincide en aplique, color, '
        'cantidad y precio', () {
      // Flor/Rojo 2 x 25: la línea a quitar (queda última en la tabla)
      seleccionar();
      cubit.onCantidadChanged('2');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();
      // Flor/Rojo a otro precio: mismo aplique y color
      cubit.onCantidadChanged('1');
      cubit.onPrecioChanged('30');
      cubit.addDetalle();
      // Luna/Verde 2 x 25: misma cantidad y precio, otro aplique y color
      cubit.onApliqueChanged(
          Aplique(id: 2, nombre: 'Luna', costoFabricacion: 4));
      cubit.onColorChanged(const StockAplique(
        apliqueId: 2,
        colorId: 9,
        colorNombre: 'Verde',
        hex: '#00FF00',
        stock: 5,
      ));
      cubit.onCantidadChanged('2');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();
      expect(cubit.state.total, 130.0); // 50 + 30 + 50

      cubit.removeDetalle(1, 5, 2.0, 25.0);

      expect(
        cubit.state.detalles.map(
            (e) => [e['idapliques'], e['idcolor'], e['cantidad'], e['precio']]),
        [
          [2, 9, 2.0, 25.0],
          [1, 5, 1.0, 30.0],
        ],
      );
      expect(cubit.state.total, 80.0);
      // (30 - 10) * 1 + (25 - 4) * 2
      expect(cubit.state.ganancias, 62.0);
    });
  });

  group('onFormSubmit', () {
    test('sin detalles devuelve false', () async {
      expect(await cubit.onFormSubmit(), false);
      expect(repo.createCalls, 0);
    });

    test('descuento inválido devuelve false', () async {
      seleccionar();
      cubit.onCantidadChanged('1');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();
      cubit.onDescuentoChanged('xx');

      expect(await cubit.onFormSubmit(), false);
      expect(repo.createCalls, 0);
    });

    test('descuento mayor al total devuelve false', () async {
      seleccionar();
      cubit.onCantidadChanged('1');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();
      cubit.onDescuentoChanged('30');

      expect(await cubit.onFormSubmit(), false);
      expect(repo.createCalls, 0);
    });

    test('válido llama createVentaAplique con totales y descuento', () async {
      seleccionar();
      cubit.onCantidadChanged('2');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();
      cubit.onDescuentoChanged('5');

      final ok = await cubit.onFormSubmit();

      expect(ok, true);
      expect(repo.createCalls, 1);
      expect(repo.lastIdsucursales, 3);
      expect(repo.lastTotal, 45.0); // 50 - 5
      expect(repo.lastGanancias, 30.0);
      expect(repo.lastDescuento, 5.0);
      expect(repo.lastDetalles!.single['cantidad'], 2.0);
    });

    test('descuento vacío se envía como 0', () async {
      seleccionar();
      cubit.onCantidadChanged('2');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();

      final ok = await cubit.onFormSubmit();

      expect(ok, true);
      expect(repo.lastDescuento, 0.0);
      expect(repo.lastTotal, 50.0);
    });

    test('error del repositorio devuelve false', () async {
      seleccionar();
      cubit.onCantidadChanged('1');
      cubit.onPrecioChanged('25');
      cubit.addDetalle();
      repo.error = Exception('fallo');

      expect(await cubit.onFormSubmit(), false);
    });
  });

  group('onApliqueChanged / onColorChanged', () {
    test('cambiar aplique resetea color y stock', () {
      seleccionar();
      cubit.onApliqueChanged(Aplique(id: 2, nombre: 'Luna'));

      expect(cubit.state.idapliques, 2);
      expect(cubit.state.idcolor, 0);
      expect(cubit.state.nombreColor, '');
      expect(cubit.state.stockDisponible, 0);
    });

    test('onColorChanged setea color y stock disponible', () {
      cubit.onColorChanged(stockRojo);
      expect(cubit.state.idcolor, 5);
      expect(cubit.state.nombreColor, 'Rojo');
      expect(cubit.state.stockDisponible, 10);
    });
  });
}
