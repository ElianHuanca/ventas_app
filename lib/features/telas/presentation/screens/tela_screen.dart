import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class TelaScreen extends StatelessWidget {
  final int id;
  const TelaScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TelaBloc, TelaState>(
      builder: (context, telaState) {
        if (telaState.isLoading) return const FullScreenLoader();
        final tela = telaState.tela!;
        return BlocProvider(
          create: (ctx) => TelaFormCubit(
            onCreateCallback: ctx.read<TelasBloc>().createTela,
            onUpdateCallback: ctx.read<TelasBloc>().updateTela,
            onDeleteCallback: ctx.read<TelasBloc>().deleteTela,
            tela: tela,
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Screen1(
              widget: [_telaInformation(context)],
              title: tela.id == 0 ? 'Crear Producto' : 'Editar Producto',
              isGridview: false,
              backRoute: true,
            ),
          ),
        );
      },
    );
  }

  Widget _telaInformation(BuildContext context) {
    return BlocBuilder<TelaFormCubit, TelaFormState>(
      builder: (context, telaForm) {
        final cubit = context.read<TelaFormCubit>();
        final tela = context.read<TelaBloc>().state.tela!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              Row(
                children: [
                  MiTextField(
                    label: 'Nombre',
                    initialValue: telaForm.nombre,
                    onChanged: cubit.onNombreChanged,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  MiTextField(
                    label: 'Precio X Menor',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue: telaForm.precxmen,
                    onChanged: cubit.onPrecxmenChanged,
                  ),
                  MiTextField(
                    label: 'Precio X Mayor',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue: telaForm.precxmay,
                    onChanged: cubit.onPrecxmayChanged,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  MiTextField(
                    label: 'Precio X Rollo',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue: telaForm.precxrollo,
                    onChanged: cubit.onPrecxrolloChanged,
                  ),
                  MiTextField(
                    label: 'Precio Compra',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue: telaForm.precxcompra,
                    onChanged: cubit.onPrecxcompraChanged,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              MaterialButtonWidget(
                onTap: () async {
                  final value =
                      await cubit.onSubmit(isUpdate: tela.id != 0);
                  if (context.mounted) showSnackbarBool(context, value);
                },
                texto: tela.id == 0 ? 'Guardar' : 'Modificar',
              ),
              const SizedBox(height: 15),
              if (tela.id != 0)
                MaterialButtonWidget(
                  onTap: () async {
                    final value = await cubit.onDeleteSubmit();
                    if (context.mounted) showSnackbarBool(context, value);
                  },
                  texto: 'Eliminar',
                ),
            ],
          ),
        );
      },
    );
  }
}
