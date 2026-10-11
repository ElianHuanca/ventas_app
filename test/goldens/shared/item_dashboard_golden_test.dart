@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/shared.dart';

import '../golden_helpers.dart';

void main() {
  testWidgets('tarjetas en la grilla de dos columnas de las pantallas',
      (tester) async {
    // Misma grilla que Screen1 con isGridview (padding 10, espacio 30)
    await montarParaCaptura(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(10),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 30,
            mainAxisSpacing: 30,
            children: [
              ItemDashboard(
                  title: 'Central', iconData: Icons.store, onTap: () {}),
              ItemDashboard(
                  title: 'Norte', iconData: Icons.store, onTap: () {}),
              ItemDashboard(
                title: '04/10/2026',
                iconData: Icons.calendar_month_rounded,
                onTap: () {},
              ),
              ItemDashboard(
                title: 'Agregar sucursal',
                iconData: Icons.add_business_rounded,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('CENTRAL'), findsOneWidget);
    await compararCaptura('item_dashboard_tarjetas');
  });
}
