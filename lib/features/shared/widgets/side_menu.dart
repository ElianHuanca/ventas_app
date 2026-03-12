import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/widgets/menu_index_cubit.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  static const _appLinkItems = ['/', '/sucursales', '/telas'];

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
          label: Text('Ventas'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.add_business_rounded),
          label: Text('Sucursales'),
        ),
        const NavigationDrawerDestination(
            icon: Icon(Icons.playlist_add), label: Text('Productos')),
      ],
    );
  }
}
