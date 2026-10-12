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
        final tela = telaState.tela;
        if (tela == null) return const CargaFallida(titulo: 'Tela');
        return BlocProvider(
          create: (ctx) => TelaFormCubit(
            onCreateCallback: ctx.read<TelasBloc>().createTela,
            onUpdateCallback: ctx.read<TelasBloc>().updateTela,
            tela: tela,
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            excludeFromSemantics: true,
            child: Screen1(
              widget: [_telaInformation(context)],
              title: tela.id == 0 ? 'Crear Tela' : 'Editar Tela',
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
              if (tela.id != 0)
                SwitchListTile(
                  title: const Text('Activo'),
                  subtitle: const Text(
                      'Las telas inactivas no se ofrecen en las ventas'),
                  value: telaForm.activo,
                  onChanged: cubit.onActivoChanged,
                ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MaterialButtonWidget(
                    onTap: () async {
                      final value =
                          await cubit.onSubmit(isUpdate: tela.id != 0);
                      if (context.mounted) showSnackbarBool(context, value);
                    },
                    texto: tela.id == 0 ? 'Guardar' : 'Modificar',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
