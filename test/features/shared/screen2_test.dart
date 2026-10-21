import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';

void main() {
  group('Screen2', () {
    late GoRouter router;

    DataTable tabla() => DataTable(
          columns: const [
            DataColumn(label: Text('Tela')),
            DataColumn(label: Text('Total')),
          ],
          rows: const [
            DataRow(cells: [DataCell(Text('Lino')), DataCell(Text('120'))]),
          ],
        );

    Future<void> montar(WidgetTester tester) async {
      router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Screen2(
              title: 'Ventas',
              subtitle: 'Sucursal Centro',
              dataTable: tabla(),
            ),
          ),
          GoRoute(
            path: '/det_venta',
            builder: (_, __) => const Scaffold(body: Text('STUB DET_VENTA')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra título, subtítulo y la tabla recibida',
        (tester) async {
      await montar(tester);

      expect(find.text('Ventas'), findsOneWidget);
      expect(find.text('Sucursal Centro'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Tela'), findsOneWidget);
      expect(find.text('Lino'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
    });

    testWidgets('el botón + navega a /det_venta', (tester) async {
      // Ojo: app_router.dart no registra /det_venta (solo
      // /det_venta/:idsucursal) y Screen2 no se usa en lib/.
      await montar(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('STUB DET_VENTA'), findsOneWidget);
    });
  });
}
