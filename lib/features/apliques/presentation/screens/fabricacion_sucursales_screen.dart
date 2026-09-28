import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';

class FabricacionSucursalesScreen extends StatelessWidget {
  const FabricacionSucursalesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SucursalesBloc, SucursalesState>(
      builder: (context, state) {
        return state.isLoading
            ? const FullScreenLoader()
            : Screen1(
                backRoute: false,
                widget: _buildBody(state.sucursales, context),
                title: 'Fabricación',
                isGridview: true,
              );
      },
    );
  }

  List<Widget> _buildBody(List<Sucursal> sucursales, BuildContext context) {
    return [
      ...sucursales
          .map((sucursal) => ItemDashboard(
                title: sucursal.nombre,
                iconData: Icons.store,
                onTap: () => context.push('/fabricacion/${sucursal.id}'),
              ))
          .toList(),
    ];
  }
}
