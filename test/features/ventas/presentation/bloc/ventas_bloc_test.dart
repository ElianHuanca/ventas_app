import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/ventas_bloc.dart';

import '../../../../helpers/fake_repositories.dart';

/// Deja la carga de ventas en espera hasta completar [carga].
class _RepoConCargaPendiente extends FakeVentasRepository {
  final carga = Completer<List<Venta>>();

  @override
  Future<List<Venta>> getVentas(int idsucursal) {
    getVentasCalls++;
    lastGetVentasSucursalId = idsucursal;
    return carga.future;
  }
}

/// Encuentra la venta pero falla al borrarla.
class _RepoQueFallaAlBorrar extends FakeVentasRepository {
  _RepoQueFallaAlBorrar({super.venta});

  @override
  Future<void> deleteVenta(int id) async => throw Exception('sin conexión');
}

Venta _venta(int id, DateTime fecha, {double total = 0}) => Venta(
      id: id,
      fecha: fecha,
      total: total,
      ganancias: 0,
      descuento: 0,
      idsucursales: 3,
    );

void main() {
  late FakeVentasRepository repo;

  final ventas = [
    _venta(1, DateTime(2024, 5, 10), total: 300),
    _venta(2, DateTime(2024, 5, 9), total: 150),
  ];

  setUp(() {
    repo = FakeVentasRepository(ventas: ventas);
  });

  Future<VentasBloc> crearBloc() async {
    final bloc = VentasBloc(ventasRepository: repo, idsucursal: 3);
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  group('carga', () {
    test('al crearse carga las ventas de su sucursal', () async {
      final bloc = await crearBloc();

      expect(bloc.state.isLoading, false);
      expect(bloc.state.ventas, ventas);
      expect(repo.lastGetVentasSucursalId, 3);
      expect(repo.getVentasCalls, 1);
    });

    test('isLoading queda en true mientras espera al repositorio', () async {
      final pendiente = _RepoConCargaPendiente();
      final bloc = VentasBloc(ventasRepository: pendiente, idsucursal: 3);
      addTearDown(bloc.close);
      await pumpEventQueue();

      expect(bloc.state.isLoading, true);

      pendiente.carga.complete(ventas);
      await pumpEventQueue();

      expect(bloc.state.isLoading, false);
      expect(bloc.state.ventas, ventas);
    });

    test('VentasLoadRequested recarga la lista', () async {
      final bloc = await crearBloc();
      final nuevas = [_venta(3, DateTime(2024, 5, 11), total: 80)];
      repo.ventas = nuevas;

      bloc.add(VentasLoadRequested(3));
      await pumpEventQueue();

      expect(bloc.state.isLoading, false);
      expect(bloc.state.ventas, nuevas);
      expect(repo.getVentasCalls, 2);
    });

    test('error del repositorio deja la lista vacía e isLoading en false',
        () async {
      repo.error = Exception('sin conexión');
      final bloc = await crearBloc();

      expect(bloc.state.isLoading, false);
      expect(bloc.state.ventas, isEmpty);
    });
  });

  group('createVenta', () {
    test('crea la venta en la sucursal y la agrega al inicio de la lista',
        () async {
      final bloc = await crearBloc();

      final creada = await bloc.createVenta(DateTime(2024, 6, 1));
      await pumpEventQueue();

      expect(repo.createVentaCalls, 1);
      expect(creada, isNotNull);
      expect(creada!.idsucursales, 3);
      expect(creada.fecha, DateTime(2024, 6, 1));
      expect(bloc.state.ventas.map((v) => v.id), [creada.id, 1, 2]);
    });

    test('si el repositorio falla devuelve null y no toca la lista', () async {
      final bloc = await crearBloc();
      repo.error = Exception('sin conexión');

      final creada = await bloc.createVenta(DateTime(2024, 6, 1));
      await pumpEventQueue();

      expect(creada, isNull);
      expect(bloc.state.ventas, ventas);
    });
  });

  group('deleteVentaIfEmpty', () {
    test('borra la venta si su total es 0', () async {
      repo.venta = _venta(5, DateTime(2024, 5, 8));
      final bloc = await crearBloc();

      await bloc.deleteVentaIfEmpty(5);

      expect(repo.ventasEliminadas, [5]);
    });

    test('no borra la venta si tiene total', () async {
      repo.venta = _venta(5, DateTime(2024, 5, 8), total: 120);
      final bloc = await crearBloc();

      await bloc.deleteVentaIfEmpty(5);

      expect(repo.ventasEliminadas, isEmpty);
    });

    test('traga el error si no puede leer la venta', () async {
      final bloc = await crearBloc();
      repo.error = Exception('sin conexión');

      await expectLater(bloc.deleteVentaIfEmpty(5), completes);
      expect(repo.ventasEliminadas, isEmpty);
    });

    test('traga el error si no puede borrarla', () async {
      repo = _RepoQueFallaAlBorrar(venta: _venta(5, DateTime(2024, 5, 8)));
      final bloc = await crearBloc();

      await expectLater(bloc.deleteVentaIfEmpty(5), completes);
    });
  });
}
