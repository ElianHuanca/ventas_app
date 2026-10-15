@Tags(['golden'])
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/presentation/screens/screens.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

void main() {
  testWidgets('una tarjeta por sucursal', (tester) async {
    // El SucursalesBloc es global en la app (main.dart): acá se inyecta
    final bloc = SucursalesBloc(
      sucursalesRepository: FakeSucursalesRepository(sucursales: [
        Sucursal(id: 1, nombre: 'Ramada'),
        Sucursal(id: 2, nombre: 'Shopping Miami Feria Barrio Lindo'),
      ]),
    );
    addTearDown(bloc.close);
    await montarParaCaptura(
      tester,
      BlocProvider.value(
        value: bloc,
        child: const InventarioSucursalesScreen(),
      ),
    );

    await compararCaptura('inventario_sucursales_screen_lista');
  });
}
