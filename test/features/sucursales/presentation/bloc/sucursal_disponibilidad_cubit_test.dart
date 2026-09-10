import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/sucursal_disponibilidad_cubit.dart';

import '../../../../helpers/fake_repositories.dart';

void main() {
  late FakeSucursalesRepository sucursalesRepo;

  const telasSucursal = [
    TelaSucursal(idtela: 1, nombre: 'Lino', disponible: true),
    TelaSucursal(idtela: 2, nombre: 'Seda', disponible: false),
  ];

  setUp(() {
    sucursalesRepo = FakeSucursalesRepository(telasSucursal: telasSucursal);
  });

  Future<SucursalDisponibilidadCubit> crearCubit() async {
    final cubit = SucursalDisponibilidadCubit(
      sucursalesRepository: sucursalesRepo,
      idsucursal: 7,
    );
    await pumpEventQueue();
    return cubit;
  }

  group('load', () {
    test('carga las telas con su disponibilidad en la sucursal', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isLoading, false);
      expect(cubit.state.telas, telasSucursal);
    });
  });

  group('toggleTela', () {
    test('marca disponible solo la tela indicada', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.toggleTela(2, true);

      expect(sucursalesRepo.setTelaSucursalCalls, [
        [2, 7, true]
      ]);
      expect(cubit.state.telas[0].disponible, true); // no cambió
      expect(cubit.state.telas[1].disponible, true); // toggled
    });

    test('desmarca una tela disponible', () async {
      final cubit = await crearCubit();
      addTearDown(cubit.close);

      await cubit.toggleTela(1, false);

      expect(cubit.state.telas[0].disponible, false);
      expect(cubit.state.telas[1].disponible, false);
    });
  });
}
