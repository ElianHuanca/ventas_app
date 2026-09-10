import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../../domain/domain.dart';
import '../../infrastructure/infrastructure.dart';
import '../bloc/bloc.dart';

class ApliqueScreen extends StatelessWidget {
  final int id;
  const ApliqueScreen({super.key, required this.id});

  static const _tamanios = [
    'Extra Chico',
    'Pequeño',
    'Chico',
    'Mediano',
    'Grande',
  ];

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
          create: (ctx) => ApliqueFormCubit(
            onCreateCallback: ctx.read<ApliquesBloc>().createAplique,
            onUpdateCallback: ctx.read<ApliquesBloc>().updateAplique,
            aplique: aplique,
          ),
          child: Screen1(
            backRoute: true,
            widget: [
              _form(context),
              if (aplique.id != 0)
                BlocProvider(
                  create: (_) => ApliqueColoresCubit(
                    apliquesRepository:
                        ApliquesRepositoryImpl(ApliquesDatasourceImpl()),
                    idaplique: aplique.id,
                  ),
                  child: _coloresSection(context),
                ),
            ],
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
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: DropdownButtonFormField<String>(
                        initialValue: form.tamanio.isEmpty ? null : form.tamanio,
                        decoration: InputDecoration(
                          labelText: 'Tamaño',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: _tamanios
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: cubit.onTamanioChanged,
                      ),
                    ),
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

  Widget _coloresSection(BuildContext context) {
    return BlocBuilder<ApliqueColoresCubit, ApliqueColoresState>(
      builder: (context, state) {
        return ProductoColoresList(
          isLoading: state.isLoading,
          colores: state.colores,
          onToggle: context.read<ApliqueColoresCubit>().toggleColor,
        );
      },
    );
  }
}
