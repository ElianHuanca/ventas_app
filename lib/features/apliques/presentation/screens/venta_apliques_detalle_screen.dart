import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class VentaApliquesDetalleScreen extends StatelessWidget {
  final int idventa;
  final DateTime? fecha;

  const VentaApliquesDetalleScreen({
    super.key,
    required this.idventa,
    this.fecha,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DetalleVentaApliquesCubit, DetalleVentaApliquesState>(
      builder: (context, state) {
        return Screen1(
          backRoute: true,
          title: fecha == null ? 'Detalle' : changeFormatDate(fecha!),
          isGridview: false,
          widget: [
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.lineas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Venta sin líneas')),
              )
            else ...[
              ...state.lineas.map((l) => ListTile(
                    title: Text(l.nombre),
                    subtitle: Text('${l.cantidad} uds x ${l.precio} Bs'),
                    trailing: Text('${l.total} Bs'),
                  )),
              const Divider(thickness: 1),
              ListTile(
                title: const Text('Total',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(
                  '${state.lineas.fold<double>(0, (sum, l) => sum + l.total)} Bs',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
