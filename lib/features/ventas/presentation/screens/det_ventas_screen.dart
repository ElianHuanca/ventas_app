import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class DetVentas extends StatelessWidget {
  final int idventa;
  const DetVentas({super.key, required this.idventa});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VentaBloc, VentaState>(
      builder: (context, ventaState) {
        return BlocBuilder<DetalleVentasBloc, DetalleVentasState>(
          builder: (context, detalleVentasState) {
            if (detalleVentasState.isLoading || ventaState.isLoading) {
              return const FullScreenLoader();
            }
            final venta = ventaState.venta!;
            final bloc = context.read<DetalleVentasBloc>();
            return Screen1(
              widget: [
                container(
                  context,
                  detalleVentasState.detalleVentas.isEmpty
                      ? const Center(
                          child: Text('Lista Vacia',
                              style: TextStyle(fontStyle: FontStyle.italic)),
                        )
                      : dataTableWidget(
                          ['Producto', 'Cantidad', 'Precio', 'Total', 'Accion'],
                          context,
                          detalleVentasState.detalleVentas,
                          venta.total,
                          venta.ganancias,
                          venta.descuento,
                          (int id) => bloc.deleteDetVenta(id),
                        ),
                ),
              ],
              title: changeFormatDate(venta.fecha),
              isGridview: false,
              backRoute: true,
              onTap: () => context.push('/det_venta/$idventa'),
            );
          },
        );
      },
    );
  }

  Container container(BuildContext context, Widget widget) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 5),
            color: Theme.of(context).primaryColor.withValues(alpha: .2),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: widget,
    );
  }
}
