import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../../domain/domain.dart';
import '../bloc/bloc.dart';

class VentasScreen extends StatelessWidget {
  final int idsucursal;
  const VentasScreen({super.key, required this.idsucursal});

  Future<void> _onCreateVenta(BuildContext context) async {
    await context.push('/det_venta/$idsucursal');
    if (context.mounted) {
      context.read<VentasBloc>().add(VentasLoadRequested(idsucursal));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VentasBloc, VentasState>(
      builder: (context, state) {
        return state.isLoading
            ? const FullScreenLoader()
            : Screen1(
                widget: _buildBody(state.ventas, context),
                title: 'Ventas',
                isGridview: true,
                backRoute: true,
                onTap: () => _onCreateVenta(context),
                tooltipAgregar: 'Registrar venta',
              );
      },
    );
  }

  List<Widget> _buildBody(List<Venta> ventas, BuildContext context) {
    return [
      ...ventas.map((venta) {
        final String fecha = changeFormatDate(venta.fecha);
        return ItemDashboard(
          title: fecha,
          iconData: Icons.calendar_month_rounded,
          onTap: () async {
            await context.push('/det_ventas/${venta.id}');
            if (context.mounted) {
              context.read<VentasBloc>().add(VentasLoadRequested(idsucursal));
            }
          },
        );
      }).toList(),
    ];
  }
}
