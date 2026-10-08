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

  group('actualizarVenta', () {
    test('envía el map y el id al repositorio y refleja la venta devuelta',
        () async {
      final bloc = await crearBloc();

      final ok = await bloc.actualizarVenta({'total': -100, 'ganancias': -40});
      await pumpEventQueue();

      expect(ok, true);
      expect(repo.actualizaciones.single, {'total': -100, 'ganancias': -40});
      expect(repo.idsActualizados, [7]);
      expect(bloc.state.venta!.total, 200);
      expect(bloc.state.venta!.ganancias, 80);
      expect(bloc.state.venta!.descuento, 10);
    });

    test('si el repositorio falla devuelve false y conserva la venta',
        () async {
      final bloc = await crearBloc();
      repo.error = Exception('sin conexión');

      final ok = await bloc.actualizarVenta({'total': -100});
      await pumpEventQueue();

      expect(ok, false);
      expect(bloc.state.venta, same(venta));
    });
  });
}
