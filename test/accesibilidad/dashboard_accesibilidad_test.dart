import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/dashboard/domain/domain.dart';
import 'package:textiles_app/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:textiles_app/features/dashboard/presentation/screens/dashboard_screen.dart';

import '../helpers/fake_repositories.dart';
import 'accesibilidad_helpers.dart';

void main() {
  Future<void> montar(WidgetTester tester, LineaDashboard linea) async {
    final cubit = DashboardCubit(
      repository: FakeDashboardRepository(
        topTelas: const [
          TopProducto(
              nombre: 'Lino', totalVendido: 4280.5, totalCantidad: 214.5),
          TopProducto(nombre: 'Seda', totalVendido: 3150, totalCantidad: 90),
          TopProducto(nombre: 'Tul', totalVendido: 1240, totalCantidad: 310),
        ],
        topApliques: const [
          TopProducto(
              nombre: 'Flor bordada 10x10',
              totalVendido: 1250,
              totalCantidad: 50),
          TopProducto(
              nombre: 'Corazón 5x5', totalVendido: 640, totalCantidad: 80),
        ],
        resumenTelas:
            const ResumenVentas(total: 8671, ganancias: 2920.4, descuento: 85),
        resumenApliques:
            const ResumenVentas(total: 1890, ganancias: 980, descuento: 20),
      ),
      linea: linea,
    );
    addTearDown(cubit.close);
    // Período fijo: el default (primer día del mes → hoy) usa DateTime.now()
    await cubit.cambiarRango(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
    await montarPantalla(
      tester,
      BlocProvider.value(value: cubit, child: const DashboardScreen()),
    );
  }

  Future<void> tocar(WidgetTester tester, String texto) async {
    await tester.tap(find.text(texto).hitTestable());
    await tester.pumpAndSettle();
  }

  group('/dashboard/telas (DashboardScreen)', () {
    verificarGuias('por total vendido',
        (tester) => montar(tester, LineaDashboard.telas));

    verificarGuias('por cantidad', (tester) async {
      await montar(tester, LineaDashboard.telas);
      await tocar(tester, 'Por cantidad');
    });
  });

  group('/dashboard/apliques (DashboardScreen)', () {
    verificarGuias('por total vendido',
        (tester) => montar(tester, LineaDashboard.apliques));
  });
}
