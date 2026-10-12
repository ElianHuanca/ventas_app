import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class SucursalScreen extends StatelessWidget {
  final int id;
  const SucursalScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SucursalBloc, SucursalState>(
      builder: (context, sucursalState) {
        if (sucursalState.isLoading) return const FullScreenLoader();
        final sucursal = sucursalState.sucursal;
        if (sucursal == null) return const CargaFallida(titulo: 'Sucursal');
        return BlocProvider(
          create: (ctx) => SucursalFormCubit(
            onCreateCallback: ctx.read<SucursalesBloc>().createSucursal,
            onUpdateCallback: ctx.read<SucursalesBloc>().updateSucursal,
            onDeleteCallback: ctx.read<SucursalesBloc>().deleteSucursal,
            sucursal: sucursal,
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Screen1(
              backRoute: true,
              widget: [_sucursalInformation(context)],
              title: sucursal.id == 0 ? 'Crear Sucursal' : 'Editar Sucursal',
              isGridview: false,
            ),
          ),
        );
      },
    );
  }

  Widget _sucursalInformation(BuildContext context) {
    return BlocBuilder<SucursalFormCubit, SucursalFormState>(
      builder: (context, sucursalForm) {
        final cubit = context.read<SucursalFormCubit>();
        final sucursal = context.read<SucursalBloc>().state.sucursal!;
        return Container(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  MiTextField(
                    label: 'Nombre',
                    initialValue: sucursalForm.nombre,
                    onChanged: cubit.onNombreChanged,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MaterialButtonWidget(
                    onTap: () async {
                      final value =
                          await cubit.onSubmit(isUpdate: sucursal.id != 0);
                      if (context.mounted) showSnackbarBool(context, value);
                    },
                    texto: sucursal.id == 0 ? 'Guardar' : 'Modificar',
                  ),
                  if (sucursal.id != 0) ...[
                    const SizedBox(width: 15),
                    MaterialButtonWidget(
                      onTap: () async {
                        final value = await cubit.onDelete();
                        if (context.mounted) showSnackbarBool(context, value);
                      },
                      texto: 'Eliminar',
                    ),
                  ],
                ],
              ),
              if (sucursal.id != 0) ...[
                const SizedBox(height: 15),
                MaterialButtonWidget(
                  onTap: () =>
                      context.push('/sucursal-disponibilidad/${sucursal.id}'),
                  texto: 'Disponibilidad de telas',
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
