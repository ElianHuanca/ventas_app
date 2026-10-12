import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../../domain/domain.dart';
import '../bloc/bloc.dart';

class ProduccionesScreen extends StatelessWidget {
  final int idsucursal;
  const ProduccionesScreen({super.key, required this.idsucursal});

  Future<void> _onCreateProduccion(BuildContext context) async {
    await context.push('/fabricacion/registro/$idsucursal');
    if (context.mounted) {
      context
          .read<ProduccionesBloc>()
          .add(ProduccionesLoadRequested(idsucursal));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProduccionesBloc, ProduccionesState>(
      builder: (context, state) {
        return state.isLoading
            ? const FullScreenLoader()
            : Screen1(
                widget: _buildBody(state.producciones, context),
                title: 'Fabricación',
                isGridview: true,
                backRoute: true,
                onTap: () => _onCreateProduccion(context),
                tooltipAgregar: 'Registrar producción',
              );
      },
    );
  }

  List<Widget> _buildBody(
      List<ProduccionCabecera> producciones, BuildContext context) {
    return [
      ...producciones.map((cab) {
        final String fecha = changeFormatDate(cab.fecha);
        return ItemDashboard(
          title: fecha,
          iconData: Icons.calendar_month_rounded,
          onTap: () async {
            await context.push('/fabricacion/detalle/${cab.id}');
            if (context.mounted) {
              context
                  .read<ProduccionesBloc>()
                  .add(ProduccionesLoadRequested(idsucursal));
            }
          },
        );
      }).toList(),
    ];
  }
}
