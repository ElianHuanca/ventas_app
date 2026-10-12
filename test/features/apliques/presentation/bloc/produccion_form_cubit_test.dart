import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';
import 'package:textiles_app/features/apliques/presentation/bloc/produccion_form_cubit.dart';

import '../../../../helpers/fake_repositories.dart';

/// La carga de apliques queda pendiente hasta completar [carga].
class _CargaLenta extends FakeApliquesRepository {
  _CargaLenta({super.apliques, super.stock, super.colores});

  final carga = Completer<void>();

  @override
  Future<List<Aplique>> getApliques({bool soloActivos = true}) async {
    await carga.future;
    return super.getApliques(soloActivos: soloActivos);
  }
}

/// El registro de la producción queda pendiente hasta completar [registro].
class _RegistroLento extends FakeApliquesRepository {
  _RegistroLento({super.apliques, super.stock, super.colores});

  final registro = Completer<void>();
  int llamadas = 0;

  @override
  Future<void> createProduccion({
    required int sucursalId,
    required DateTime fecha,
    required List<Map<String, dynamic>> lineas,
  }) async {
    llamadas++;
    await registro.future;
    return super
        .createProduccion(sucursalId: sucursalId, fecha: fecha, lineas: lineas);
  }
}

void main() {
  late FakeApliquesRepository repo;

  final apliques = [
    Aplique(id: 1, nombre: 'Flor'),
    Aplique(id: 2, nombre: 'Luna'),
  ];
  const colores = [
    ColorItem(id: 1, nombre: 'Rojo', hex: '#FF0000', vinculado: true),
    ColorItem(id: 2, nombre: 'Verde', vinculado: false),
    ColorItem(id: 3, nombre: 'Azul', hex: '#0000FF', vinculado: true),
  ];
  const stockCentro = [
    StockAplique(
        apliqueId: 1,
        colorId: 1,
        colorNombre: 'Rojo',
        hex: '#FF0000',
        stock: 7),
  ];

  setUp(() {
    repo = FakeApliquesRepository(
      apliques: apliques,
      colores: colores,
      stock: stockCentro,
    );
  });

  Future<ProduccionFormCubit> crearCubit() async {
    final cubit = ProduccionFormCubit(apliquesRepository: repo, idsucursal: 1);
    await pumpEventQueue();
    return cubit;
  }

  /// Deja el formulario con Flor + Rojo + cantidad '3' listos para añadir.
  Future<void> seleccionarLinea(ProduccionFormCubit cubit,
      {String cantidad = '3'}) async {
    await cubit.onApliqueChanged(apliques[0]);
    cubit.onColorChanged(colores[0]);
    cubit.onCantidadChanged(cantidad);
  }

  group('load', () {
    test('carga apliques y stock de la sucursal al crearse', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isLoading, false);
      expect(cubit.state.apliques, apliques);
      expect(cubit.state.stock, stockCentro);
      expect(cubit.state.idsucursal, 1);
      expect(repo.lastGetStockSucursalId, 1);
    });

    test('mientras carga marca isLoading y al terminar lo apaga', () async {
      final lento =
          _CargaLenta(apliques: apliques, colores: colores, stock: stockCentro);
      final cubit =
          ProduccionFormCubit(apliquesRepository: lento, idsucursal: 1);
      addTearDown(cubit.close);

      try {
        await pumpEventQueue();
        expect(cubit.state.isLoading, isTrue);
      } finally {
        lento.carga.complete();
      }
      await pumpEventQueue();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.apliques, apliques);
    });

    test('error del repositorio deja isLoading en false', () async {
      repo.error = Exception('fallo');
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isLoading, false);
      expect(cubit.state.apliques, isEmpty);
      expect(cubit.state.stock, isEmpty);
    });
  });

  group('onApliqueChanged', () {
    test('carga solo los colores vinculados al aplique', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.onApliqueChanged(apliques[0]);

      expect(repo.lastGetColoresApliqueId, 1);
      expect(cubit.state.colores.map((e) => e.id), [1, 3]);
      expect(cubit.state.apliqueNombre, 'Flor');
    });

    test('con null limpia selección y no consulta colores', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.onApliqueChanged(null);

      expect(cubit.state.idapliques, 0);
      expect(cubit.state.apliqueNombre, '');
      expect(cubit.state.colores, isEmpty);
      expect(repo.lastGetColoresApliqueId, isNull);
    });
  });

  group('onFechaChanged', () {
    test('la fecha por defecto es hoy y se puede cambiar', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      final hoy = DateTime.now();
      expect(cubit.state.fecha.year, hoy.year);
      expect(cubit.state.fecha.month, hoy.month);
      expect(cubit.state.fecha.day, hoy.day);

      final otra = DateTime(2024, 5, 10);
      cubit.onFechaChanged(otra);
      expect(cubit.state.fecha, otra);
    });
  });

  group('stockActual', () {
    test('devuelve el stock del aplique+color seleccionados', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      await cubit.onApliqueChanged(apliques[0]);

      cubit.onColorChanged(colores[0]); // Rojo, stock 7
      expect(cubit.state.stockActual, 7);

      cubit.onColorChanged(colores[2]); // Azul, sin fila de inventario
      expect(cubit.state.stockActual, 0);
    });
  });

  group('addDetalleProduccion', () {
    test('valida aplique, color y cantidad', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.addDetalleProduccion(), 'Seleccione un aplique');

      await cubit.onApliqueChanged(apliques[0]);
      expect(cubit.addDetalleProduccion(), 'Seleccione un color');

      cubit.onColorChanged(colores[0]);
      expect(cubit.addDetalleProduccion(),
          'Ingrese una cantidad válida mayor a 0');

      cubit.onCantidadChanged('abc');
      expect(cubit.addDetalleProduccion(),
          'Ingrese una cantidad válida mayor a 0');

      cubit.onCantidadChanged('-2');
      expect(cubit.addDetalleProduccion(),
          'Ingrese una cantidad válida mayor a 0');

      cubit.onCantidadChanged('0');
      expect(cubit.addDetalleProduccion(),
          'Ingrese una cantidad válida mayor a 0');

      expect(cubit.state.detProducciones, isEmpty);
    });

    test('añade la línea con nombres y limpia la cantidad', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      await seleccionarLinea(cubit);

      final error = cubit.addDetalleProduccion();

      expect(error, isNull);
      expect(cubit.state.detProducciones.single, {
        'idaplique': 1,
        'apliqueNombre': 'Flor',
        'idcolor': 1,
        'colorNombre': 'Rojo',
        'hex': '#FF0000',
        'cantidad': 3.0,
      });
      expect(cubit.state.cantidad, '');
    });

    test('mismo aplique+color suma la cantidad en vez de duplicar', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      await seleccionarLinea(cubit, cantidad: '3');
      cubit.addDetalleProduccion();
      cubit.onCantidadChanged('2');
      cubit.addDetalleProduccion();

      expect(cubit.state.detProducciones.length, 1);
      expect(cubit.state.detProducciones.single['cantidad'], 5.0);
    });

    test('distinto color agrega otra línea', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      await seleccionarLinea(cubit, cantidad: '3');
      cubit.addDetalleProduccion();
      cubit.onColorChanged(colores[2]); // Azul
      cubit.onCantidadChanged('1');
      cubit.addDetalleProduccion();

      expect(cubit.state.detProducciones.length, 2);
    });
  });

  group('removeDetalleProduccion', () {
    test('quita la línea del listado', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      await seleccionarLinea(cubit);
      cubit.addDetalleProduccion();

      cubit.removeDetalleProduccion(1, 1, 3.0);

      expect(cubit.state.detProducciones, isEmpty);
    });

    test('con datos inexistentes no modifica el listado', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      await seleccionarLinea(cubit);
      cubit.addDetalleProduccion();

      cubit.removeDetalleProduccion(1, 1, 99.0);
      cubit.removeDetalleProduccion(2, 1, 3.0);

      expect(cubit.state.detProducciones.length, 1);
    });
  });

  group('onFormSubmit', () {
    test('con el listado vacío devuelve error y no llama al repositorio',
        () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      final error = await cubit.onFormSubmit();

      expect(error, 'Añada al menos una línea al listado');
      expect(repo.produccionesCreadas, isEmpty);
    });

    test(
        'envía todas las líneas con la fecha, limpia el listado y refresca stock',
        () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      final fecha = DateTime(2024, 5, 10);
      cubit.onFechaChanged(fecha);
      await seleccionarLinea(cubit, cantidad: '3');
      cubit.addDetalleProduccion();
      cubit.onColorChanged(colores[2]); // Azul
      cubit.onCantidadChanged('2');
      cubit.addDetalleProduccion();
      const stockActualizado = [
        StockAplique(
            apliqueId: 1,
            colorId: 1,
            colorNombre: 'Rojo',
            hex: '#FF0000',
            stock: 10),
      ];
      repo.stock = stockActualizado;

      final error = await cubit.onFormSubmit();

      expect(error, isNull);
      expect(repo.produccionesCreadas.single, {
        'sucursalId': 1,
        'fecha': fecha,
        'lineas': [
          {'idaplique': 1, 'idcolor': 3, 'cantidad': 2.0},
          {'idaplique': 1, 'idcolor': 1, 'cantidad': 3.0},
        ],
      });
      expect(cubit.state.detProducciones, isEmpty);
      expect(cubit.state.stock, stockActualizado);
      expect(cubit.state.isSubmitting, false);
    });

    test(
        'mientras registra marca isSubmitting y un segundo envío no vuelve a '
        'registrar el lote', () async {
      final lento = _RegistroLento(
          apliques: apliques, colores: colores, stock: stockCentro);
      repo = lento;
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      await seleccionarLinea(cubit);
      cubit.addDetalleProduccion();

      final primero = cubit.onFormSubmit();
      final Future<String?> segundo;
      try {
        expect(cubit.state.isSubmitting, isTrue);
        segundo = cubit.onFormSubmit(); // doble toque en Guardar
        await pumpEventQueue();
        expect(lento.llamadas, 1);
      } finally {
        lento.registro.complete();
      }

      expect(await primero, isNull);
      await segundo;
      expect(lento.produccionesCreadas, hasLength(1));
      expect(cubit.state.isSubmitting, isFalse);
    });

    test('error del repositorio devuelve mensaje sin prefijo Exception:',
        () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);
      await seleccionarLinea(cubit);
      cubit.addDetalleProduccion();
      repo.error = Exception('stock negativo');

      final error = await cubit.onFormSubmit();

      expect(error, 'stock negativo');
      expect(cubit.state.isSubmitting, false);
      expect(cubit.state.detProducciones.length, 1);
    });
  });
}
