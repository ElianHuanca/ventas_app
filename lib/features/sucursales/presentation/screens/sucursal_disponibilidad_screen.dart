import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class SucursalDisponibilidadScreen extends StatelessWidget {
  const SucursalDisponibilidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SucursalDisponibilidadCubit, SucursalDisponibilidadState>(
      builder: (context, state) {
        final cubit = context.read<SucursalDisponibilidadCubit>();
        if (state.isLoading) return const FullScreenLoader();
        return Screen1(
          backRoute: true,
          title: 'Disponibilidad de telas',
          isGridview: false,
          widget: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Activá qué telas se pueden vender en esta sucursal. '
                      'Si no activás ninguna, la venta muestra todo el catálogo.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  ...state.telas.map((tela) => SwitchListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(tela.nombre),
                        value: tela.disponible,
                        onChanged: (valor) =>
                            cubit.toggleTela(tela.idtela, valor),
                      )),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
