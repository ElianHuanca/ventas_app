@Tags(['golden'])
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/sucursales/presentation/screens/screens.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

// La pantalla solo gestiona telas: el inventario de apliques por sucursal no
// se muestra acá (vive en Fabricación y en la venta de apliques).
void main() {
  Future<void> montar(
    WidgetTester tester,
    FakeSucursalesRepository repo,
  ) async {
    final cubit = SucursalDisponibilidadCubit(
      sucursalesRepository: repo,
      idsucursal: 1,
    );
    addTearDown(cubit.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: cubit,
        child: const SucursalDisponibilidadScreen(),
      ),
    );
  }

  testWidgets('telas vinculadas y no vinculadas a la sucursal', (tester) async {
    await montar(
      tester,
      FakeSucursalesRepository(telasSucursal: const [
        TelaSucursal(idtela: 1, nombre: 'Lino', disponible: true),
        TelaSucursal(idtela: 2, nombre: 'Seda', disponible: false),
        TelaSucursal(idtela: 3, nombre: 'Gabardina', disponible: true),
        TelaSucursal(idtela: 4, nombre: 'Popelina', disponible: false),
        TelaSucursal(idtela: 5, nombre: 'Tul', disponible: true),
      ]),
    );

    await compararCaptura('sucursal_disponibilidad');
  });

  testWidgets('sin telas en el catálogo solo muestra la ayuda', (tester) async {
    await montar(tester, FakeSucursalesRepository());

    await compararCaptura('sucursal_disponibilidad_vacia');
  });
}
