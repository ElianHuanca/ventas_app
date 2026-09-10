import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class ApliquesScreen extends StatelessWidget {
  const ApliquesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApliquesBloc, ApliquesState>(
      builder: (context, state) {
        return state.isLoading
            ? const FullScreenLoader()
            : Screen1(
                backRoute: false,
                widget: _buildBody(context, state),
                title: 'Apliques',
                isGridview: false,
                onTap: () async {
                  await context.push('/aplique/0');
                  if (context.mounted) {
                    context.read<ApliquesBloc>().add(ApliquesLoadRequested());
                  }
                },
              );
      },
    );
  }

  List<Widget> _buildBody(BuildContext context, ApliquesState state) {
    if (state.apliques.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No hay apliques registrados')),
        ),
      ];
    }
    return state.apliques
        .map((aplique) => ListTile(
              title: Text(aplique.nombre),
              subtitle: Text(
                '${aplique.tamanio.isEmpty ? 'Sin tamaño' : aplique.tamanio}'
                ' · Costo fabricación: ${aplique.costoFabricacion} Bs',
              ),
              trailing: aplique.activo
                  ? null
                  : const Icon(Icons.visibility_off, size: 18),
              onTap: () async {
                await context.push('/aplique/${aplique.id}');
                if (context.mounted) {
                  context.read<ApliquesBloc>().add(ApliquesLoadRequested());
                }
              },
            ))
        .toList();
  }
}
