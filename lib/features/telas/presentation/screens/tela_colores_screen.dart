import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class TelaColoresScreen extends StatelessWidget {
  final int idtela;
  const TelaColoresScreen({super.key, required this.idtela});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TelaColoresCubit, TelaColoresState>(
      builder: (context, state) {
        final titulo =
            state.nombreTela.isEmpty ? 'Colores de la tela' : state.nombreTela;
        return Screen1(
          backRoute: true,
          title: titulo,
          isGridview: false,
          widget: [
            ProductoColoresList(
              isLoading: state.isLoading,
              colores: state.colores,
              onToggle: context.read<TelaColoresCubit>().toggleColor,
            ),
          ],
        );
      },
    );
  }
}
