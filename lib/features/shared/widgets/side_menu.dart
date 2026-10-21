import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:textiles_app/features/shared/widgets/menu_index_cubit.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  static const _appLinkItems = [
    '/',
    '/venta-apliques',
    '/fabricacion',
    '/inventario',
    '/sucursales',
    '/telas',
    '/apliques',
    '/colores',
    '/dashboard/telas',
    '/dashboard/apliques',
  ];

  @override
  Widget build(BuildContext context) {
    final hasNotch = MediaQuery.of(context).viewPadding.top > 35;
    final textStyles = Theme.of(context).textTheme;
    final menuIndexState = context.watch<MenuIndexCubit>().state;

    return NavigationDrawer(
      elevation: 1,
      selectedIndex: menuIndexState.index,
      onDestinationSelected: (value) {
        context.read<MenuIndexCubit>().setIndex(value);
        context.go(_appLinkItems[value]);
        if (context.mounted) Navigator.of(context).pop();
      },
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, hasNotch ? 0 : 20, 16, 10),
          child: Text('Menú', style: textStyles.titleMedium),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.add_shopping_cart_rounded),
          label: Text('Venta telas'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.auto_awesome_rounded),
          label: Text('Venta apliques'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.precision_manufacturing_rounded),
          label: Text('Fabricación'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.inventory_2_rounded),
          label: Text('Inventario'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.add_business_rounded),
          label: Text('Sucursales'),
        ),
        const NavigationDrawerDestination(
            icon: Icon(Icons.playlist_add), label: Text('Telas')),
        const NavigationDrawerDestination(
            icon: Icon(Icons.category_rounded), label: Text('Apliques')),
        const NavigationDrawerDestination(
            icon: Icon(Icons.palette_rounded), label: Text('Colores')),
        // Submenú: NavigationDrawer solo numera los destinos que son hijos
        // directos, así que va como sección (título + destinos)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 16, 10),
          child: Text('Dashboard', style: textStyles.titleSmall),
        ),
        // El lector de pantalla no ve el título de la sección al tocar
        const NavigationDrawerDestination(
          icon: Icon(Icons.bar_chart_rounded),
          label: Text('Telas', semanticsLabel: 'Dashboard telas'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.bar_chart_rounded),
          label: Text('Apliques', semanticsLabel: 'Dashboard apliques'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Divider(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Cerrar sesión'),
            subtitle: Text(context.read<AuthRepository>().email ?? ''),
            // El router manda a /login al detectar que no hay sesión
            onTap: () => context.read<AuthRepository>().cerrarSesion(),
          ),
        ),
      ],
    );
  }
}
