import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class ColoresScreen extends StatelessWidget {
  const ColoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ColoresBloc, ColoresState>(
      builder: (context, state) {
        return state.isLoading
            ? const FullScreenLoader()
            : Screen1(
                backRoute: false,
                widget: _buildBody(context, state),
                title: 'Colores',
                isGridview: false,
                onTap: () async {
                  await context.push('/color/0');
                  if (context.mounted) {
                    context.read<ColoresBloc>().add(ColoresLoadRequested());
                  }
                },
              );
      },
    );
  }

  List<Widget> _buildBody(BuildContext context, ColoresState state) {
    if (state.colores.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No hay colores registrados')),
        ),
      ];
    }
    return state.colores
        .map((color) => ListTile(
              leading: MuestraColor(hex: color.hex, radio: 12),
              title: Text(color.nombre),
              subtitle: Text('#${color.hex}'),
              onTap: () async {
                await context.push('/color/${color.id}');
                if (context.mounted) {
                  context.read<ColoresBloc>().add(ColoresLoadRequested());
                }
              },
            ))
        .toList();
  }
}
