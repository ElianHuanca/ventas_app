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
        return Screen1(
          backRoute: true,
          title: 'Colores del aplique',
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
