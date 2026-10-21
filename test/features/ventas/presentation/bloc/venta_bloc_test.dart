import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import 'package:textiles_app/features/ventas/presentation/bloc/venta_bloc.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeVentasRepository repo;

  final venta = Venta(
    id: 7,
    fecha: DateTime(2024, 5, 10),
    total: 300,
    ganancias: 120,
    descuento: 10,
    idsucursales: 1,
  );

  setUp(() {
    repo = FakeVentasRepository(venta: venta);
  });

  Future<VentaBloc> crearBloc() async {
    final bloc = VentaBloc(ventasRepository: repo, id: 7);
    addTearDown(bloc.close);
    await pumpEventQueue();
    return bloc;
  }

  group('carga', () {
    test('arranca cargando', () {
      final bloc = VentaBloc(ventasRepository: repo, id: 7);
      addTearDown(bloc.close);

      expect(bloc.state.isLoading, true);
      expect(bloc.state.venta, isNull);
    });

    test('al crearse carga la venta pedida', () async {
      final bloc = await crearBloc();

      expect(bloc.state.isLoading, false);
      expect(bloc.state.venta, same(venta));
    });

    test('error del repositorio deja isLoading en false y sin venta', () async {
      repo.error = Exception('sin conexión');
      final bloc = await crearBloc();

      expect(bloc.state.isLoading, false);
      expect(bloc.state.venta, isNull);
    });
  });

  group('mostrarVenta', () {
    final descontada = Venta(
      id: 7,
      fecha: DateTime(2024, 5, 10),
      total: 200,
      ganancias: 80,
      descuento: 10,
      idsucursales: 1,
    );

    test('muestra la venta que devolvió la base sin volver a leerla',
        () async {
      final bloc = await crearBloc();
      // Si la releyera, mostraría esta
      repo.venta = venta;

      bloc.mostrarVenta(descontada);
      await pumpEventQueue();

      expect(bloc.state.venta, same(descontada));
      expect(bloc.state.isLoading, false);
    });

    test('sin venta (la línea ya no estaba) la vuelve a leer', () async {
      final bloc = await crearBloc();
      repo.venta = descontada;

      bloc.mostrarVenta(null);
      await pumpEventQueue();

      expect(bloc.state.venta, same(descontada));
      expect(bloc.state.isLoading, false);
    });

    test('si la relectura falla conserva la venta que mostraba', () async {
      final bloc = await crearBloc();
      repo.error = Exception('sin conexión');

      bloc.mostrarVenta(null);
      await pumpEventQueue();

      expect(bloc.state.venta, same(venta));
    });
  });
}
