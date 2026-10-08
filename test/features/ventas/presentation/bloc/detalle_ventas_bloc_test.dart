import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/detalle_ventas_bloc.dart';

import '../../../../helpers/fake_repositories.dart';

/// Devuelve las líneas creadas con id, como el upsert real.
class _RepoQueDevuelveCreadas extends FakeDetalleVentasRepository {
  _RepoQueDevuelveCreadas({super.detalles});

  @override
  Future<List<DetalleVenta>> createDetalleVenta(
      List<Map<String, dynamic>> detalleVentasLike, int idventas) async {
    await super.createDetalleVenta(detalleVentasLike, idventas);
    var id = 100;
    return detalleVentasLike
        .map((d) => DetalleVenta(
              id: id++,
              nombre: d['nombre'],
              precio: (d['precio'] as num).toDouble(),
              cantidad: (d['cantidad'] as num).toDouble(),
              total: (d['total'] as num).toDouble(),
              ganancias: (d['ganancias'] as num).toDouble(),
              idtelas: d['idtelas'],
            ))
        .toList();
  }
}

void main() {
  late FakeDetalleVentasRepository repo;
  late List<Map<String, dynamic>> actualizacionesVenta;
  late bool resultadoUpdateVenta;

  const detalles = [
    DetalleVenta(
        id: 1,
        nombre: 'Lino',
        precio: 100,
        cantidad: 2,
        total: 200,
        ganancias: 80,
        idtelas: 1),
    DetalleVenta(
        id: 2,
        nombre: 'Seda',
        precio: 45,
        cantidad: 3,
        total: 135,
        ganancias: 45,
        idtelas: 2),
  ];

  setUp(() {
    repo = _RepoQueDevuelveCreadas(detalles: detalles);
    actualizacionesVenta = [];
    resultadoUpdateVenta = true;
  });

  Future<DetalleVentasBloc> crearBloc() async {
    final bloc = DetalleVentasBloc(
      detalleVentasRepository: repo,
      updateVenta: (ventaLike) async {
        actualizacionesVenta.add(ventaLike);
        return resultadoUpdateVenta;
      },
      idventa: 5,
    );
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  group('carga', () {
    test('al crearse carga las líneas de la venta', () async {
      final bloc = await crearBloc();

      expect(bloc.state.isLoading, false);
      expect(bloc.state.detalleVentas, detalles);
      expect(repo.lastGetDetalleIdventa, 5);
    });

    test('venta sin líneas deja la lista vacía e isLoading en false', () async {
      repo.detalles = const [];
      final bloc = await crearBloc();

      expect(bloc.state.isLoading, false);
      expect(bloc.state.detalleVentas, isEmpty);
    });

    test('error del repositorio deja la lista vacía e isLoading en false',
        () async {
      repo.error = Exception('sin conexión');
      final bloc = await crearBloc();

      expect(bloc.state.isLoading, false);
      expect(bloc.state.detalleVentas, isEmpty);
    });
  });

  group('createDetVenta', () {
    test('envía las líneas con el idventa y agrega las creadas al inicio',
        () async {
      final bloc = await crearBloc();
      final nuevas = [
        {
          'idtelas': 3,
          'nombre': 'Raso',
          'cantidad': 1.0,
          'precio': 60.0,
          'total': 60.0,
          'ganancias': 20.0,
        },
      ];

      final ok = await bloc.createDetVenta(nuevas);
      await pumpEventQueue();

      expect(ok, true);
      expect(repo.detallesCreados.single, nuevas);
      expect(repo.idsVentaUsados, [5]);
      expect(bloc.state.detalleVentas.map((d) => d.nombre),
          ['Raso', 'Lino', 'Seda']);
    });

    test('si el repositorio falla devuelve false y no toca la lista', () async {
      final bloc = await crearBloc();
      repo.error = Exception('sin conexión');

      final ok = await bloc.createDetVenta([
        {'idtelas': 3, 'cantidad': 1.0, 'precio': 60.0},
      ]);
      await pumpEventQueue();

      expect(ok, false);
      expect(bloc.state.detalleVentas, detalles);
    });
  });

  group('deleteDetVenta', () {
    test('borra la línea y descuenta su total y ganancias de la venta (deltas)',
        () async {
      final bloc = await crearBloc();

      final ok = await bloc.deleteDetVenta(1);
      await pumpEventQueue();

      expect(ok, true);
      expect(repo.detallesEliminados, [1]);
      // Convención incremental: se envían deltas negativos, no el total nuevo
      expect(
          actualizacionesVenta.single, {'total': -200.0, 'ganancias': -80.0});
      expect(bloc.state.detalleVentas.map((d) => d.id), [2]);
    });

    test('devuelve false si no se pudo actualizar la venta', () async {
      final bloc = await crearBloc();
      resultadoUpdateVenta = false;

      final ok = await bloc.deleteDetVenta(1);

      expect(ok, false);
      expect(actualizacionesVenta, hasLength(1));
    });

    test('si el repositorio falla devuelve false y no toca la venta', () async {
      final bloc = await crearBloc();
      repo.error = Exception('sin conexión');

      final ok = await bloc.deleteDetVenta(1);
      await pumpEventQueue();

      expect(ok, false);
      expect(actualizacionesVenta, isEmpty);
      expect(bloc.state.detalleVentas, detalles);
    });
  });
}
