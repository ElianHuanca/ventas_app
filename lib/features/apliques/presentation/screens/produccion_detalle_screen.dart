import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class ProduccionDetalleScreen extends StatelessWidget {
  final int idproduccion;
  const ProduccionDetalleScreen({super.key, required this.idproduccion});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DetalleProduccionCubit, DetalleProduccionState>(
      builder: (context, state) {
        return Screen1(
          backRoute: true,
          title: _titulo(state),
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
                child:
                    Center(child: Text('Todavía no hay producciones registradas')),
              )
            else
              ...state.lineas.map((p) => ListTile(
                    leading: CircleAvatar(
                      radius: 10,
                      backgroundColor: colorFromHex(p.hex),
                    ),
                    title: Text('${p.apliqueNombre} (${p.colorNombre})'),
                    subtitle: Text(p.sucursalNombre),
                    trailing: Text('${p.cantidad} uds'),
                  )),
          ],
        );
      },
    );
  }

  String _titulo(DetalleProduccionState state) {
    if (state.lineas.isEmpty) return 'Detalle';
    final fecha = DateTime.tryParse(state.lineas.first.fecha);
    return fecha == null ? 'Detalle' : changeFormatDate(fecha);
  }
}
