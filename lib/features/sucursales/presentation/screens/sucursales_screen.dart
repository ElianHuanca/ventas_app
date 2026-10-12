import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../../domain/domain.dart';
import '../bloc/bloc.dart';

class SucursalesScreen extends StatelessWidget {
  final bool gSucursales;
  const SucursalesScreen(this.gSucursales, {super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SucursalesBloc, SucursalesState>(
      builder: (context, state) {
        return state.isLoading
            ? const FullScreenLoader()
            : Screen1(
                backRoute: false,
                widget: _buildBody(state.sucursales, context, gSucursales),
                title: 'Sucursales',
                isGridview: true,
              );
      },
    );
  }

  List<Widget> _buildBody(
      List<Sucursal> sucursales, BuildContext context, bool gSucursales) {
    return [
      ...sucursales
          .map((sucursal) => ItemDashboard(
              title: sucursal.nombre,
              iconData: Icons.store,
              onTap: () => gSucursales
                  ? context.push('/sucursal/${sucursal.id}')
                  : context.push('/ventas/${sucursal.id}')))
          .toList(),
      if (gSucursales)
        ItemDashboard(
            title: 'Agregar Sucursal',
            iconData: Icons.add_business_rounded,
            onTap: () => context.push('/sucursal/0'))
      else
        const SizedBox(),
    ];
  }
}
