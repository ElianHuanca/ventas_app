import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../../domain/domain.dart';
import '../bloc/bloc.dart';

class ApliqueScreen extends StatelessWidget {
  final int id;
  const ApliqueScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApliquesBloc, ApliquesState>(
      builder: (context, state) {
        if (state.isLoading) return const FullScreenLoader();
        final aplique = state.apliques
            .where((e) => e.id == id)
            .firstOrNull ??
            Aplique.empty();
        return BlocProvider(
          // El primer frame llega con la lista vacía (id 0): la key recrea el
          // formulario cuando aparece el aplique, aunque no se haya llegado a
          // dibujar el loader (si no, editar crearía un duplicado)
          key: ValueKey(aplique.id),
          create: (ctx) => ApliqueFormCubit(
            onCreateCallback: ctx.read<ApliquesBloc>().createAplique,
            onUpdateCallback: ctx.read<ApliquesBloc>().updateAplique,
            aplique: aplique,
          ),
          child: Screen1(
            backRoute: true,
            widget: [_form(context)],
            title: aplique.id == 0 ? 'Crear Aplique' : 'Editar Aplique',
            isGridview: false,
          ),
        );
      },
    );
  }

  Widget _form(BuildContext context) {
    return BlocBuilder<ApliqueFormCubit, ApliqueFormState>(
      builder: (context, form) {
        final cubit = context.read<ApliqueFormCubit>();
        return Container(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  MiTextField(
                    label: 'Nombre',
                    initialValue: form.nombre,
                    onChanged: cubit.onNombreChanged,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  MiTextField(
                    label: 'Ancho (cm)',
                    initialValue: form.anchoCm,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: cubit.onAnchoChanged,
                  ),
                  MiTextField(
                    label: 'Alto (cm)',
                    initialValue: form.altoCm,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: cubit.onAltoChanged,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  MiTextField(
                    label: 'Costo de fabricación',
                    initialValue: form.costoFabricacion,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: cubit.onCostoChanged,
                  ),
                ],
              ),
              if (form.id != 0)
                SwitchListTile(
                  title: const Text('Activo'),
                  subtitle: const Text(
                      'Los apliques inactivos no se ofrecen en las ventas'),
                  value: form.activo,
                  onChanged: cubit.onActivoChanged,
                ),
              const SizedBox(height: 20),
              MaterialButtonWidget(
                onTap: () async {
                  final value = await cubit.onSubmit(isUpdate: form.id != 0);
                  if (context.mounted) showSnackbarBool(context, value);
                },
                texto: form.id == 0 ? 'Guardar' : 'Modificar',
              ),
            ],
          ),
        );
      },
    );
  }
}
