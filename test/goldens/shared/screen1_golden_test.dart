@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/auth.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/shared/widgets/menu_index_cubit.dart';

import '../../helpers/fake_repositories.dart';
import '../golden_helpers.dart';

void main() {
  testWidgets('grilla de pantalla raíz: menú, título y tarjetas',
      (tester) async {
    // Sin backRoute lleva SideMenu como drawer: necesita sus providers
    final menuCubit = MenuIndexCubit();
    addTearDown(menuCubit.close);
    await montarParaCaptura(
      tester,
      RepositoryProvider<AuthRepository>.value(
        value: FakeAuthRepository(),
        child: BlocProvider.value(
          value: menuCubit,
          child: Screen1(
            backRoute: false,
            title: 'Sucursales',
            isGridview: true,
            widget: [
              ItemDashboard(
                  title: 'Central', iconData: Icons.store, onTap: () {}),
              ItemDashboard(
                  title: 'Norte', iconData: Icons.store, onTap: () {}),
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

    expect(find.byIcon(Icons.menu), findsOneWidget);
    await compararCaptura('screen1_grilla');
  });

  testWidgets('lista de pantalla interna: volver y botón agregar',
      (tester) async {
    await montarParaCaptura(
      tester,
      Screen1(
        backRoute: true,
        title: 'Telas',
        isGridview: false,
        onTap: () {},
        widget: const [
          ListTile(
            leading: Icon(Icons.texture_rounded),
            title: Text('Lino'),
            subtitle: Text('Menor 45 Bs · Mayor 40 Bs'),
          ),
          ListTile(
            leading: Icon(Icons.texture_rounded),
            title: Text('Seda'),
            subtitle: Text('Menor 60 Bs · Mayor 55 Bs'),
          ),
          ListTile(
            leading: Icon(Icons.texture_rounded),
            title: Text('Gabardina'),
            subtitle: Text('Menor 35 Bs · Mayor 30 Bs'),
          ),
        ],
      ),
    );

    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    await compararCaptura('screen1_lista');
  });
}
