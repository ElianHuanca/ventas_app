import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class ProduccionesHistorialScreen extends StatelessWidget {
  const ProduccionesHistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProduccionesHistorialCubit, ProduccionesHistorialState>(
      builder: (context, state) {
        return Screen1(
          backRoute: true,
          title: 'Producciones recientes',
          isGridview: false,
          widget: [
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.producciones.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Todavía no hay producciones registradas')),
              )
            else
              ...state.producciones.map((p) => ListTile(
                    leading: CircleAvatar(
                      radius: 10,
                      backgroundColor: colorFromHex(p.hex),
                    ),
                    title: Text('${p.apliqueNombre} (${p.colorNombre})'),
                    subtitle: Text('${p.sucursalNombre} · ${p.fecha}'),
                    trailing: Text('${p.cantidad} uds'),
                  )),
          ],
        );
      },
    );
  }
}
