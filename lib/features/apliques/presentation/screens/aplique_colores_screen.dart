import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class ApliqueColoresScreen extends StatelessWidget {
  final int idaplique;
  const ApliqueColoresScreen({super.key, required this.idaplique});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApliqueColoresCubit, ApliqueColoresState>(
      builder: (context, state) {
        // El nombre viene como "Flor Petalo Suizo Grande - Bolsa x100 und":
        // el título muestra solo la parte anterior al guion.
        final titulo = state.nombreAplique.isEmpty
            ? 'Colores del aplique'
            : state.nombreAplique.split(' - ').first;
        return Screen1(
          backRoute: true,
          title: titulo,
          isGridview: false,
          widget: [
            ProductoColoresList(
              isLoading: state.isLoading,
              colores: state.colores,
              onToggle: context.read<ApliqueColoresCubit>().toggleColor,
            ),
          ],
        );
      },
    );
  }
}
