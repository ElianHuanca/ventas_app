import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../../domain/domain.dart';
import '../bloc/bloc.dart';

class VentasApliquesScreen extends StatelessWidget {
  final int idsucursal;
  const VentasApliquesScreen({super.key, required this.idsucursal});

  Future<void> _onCreateVenta(BuildContext context) async {
    await context.push('/venta-apliques/registro/$idsucursal');
    if (context.mounted) {
      context
          .read<VentasApliquesBloc>()
          .add(VentasApliquesLoadRequested(idsucursal));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VentasApliquesBloc, VentasApliquesState>(
      builder: (context, state) {
        return state.isLoading
            ? const FullScreenLoader()
            : Screen1(
                widget: _buildBody(state.ventas, context),
                title: 'Venta de Apliques',
                isGridview: true,
                backRoute: true,
                onTap: () => _onCreateVenta(context),
                tooltipAgregar: 'Registrar venta',
              );
      },
    );
  }

  List<Widget> _buildBody(List<VentaAplique> ventas, BuildContext context) {
    return [
      ...ventas.map((venta) {
        final String fecha = changeFormatDate(venta.fecha);
        return ItemDashboard(
          title: fecha,
          iconData: Icons.calendar_month_rounded,
          onTap: () async {
            await context.push(Uri(
              path: '/venta-apliques/detalle/${venta.id}',
              queryParameters: {'fecha': venta.fecha.toIso8601String()},
            ).toString());
            if (context.mounted) {
              context
                  .read<VentasApliquesBloc>()
                  .add(VentasApliquesLoadRequested(idsucursal));
            }
          },
        );
      }).toList(),
    ];
  }
}
