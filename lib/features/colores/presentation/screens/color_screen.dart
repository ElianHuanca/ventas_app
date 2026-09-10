import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../bloc/bloc.dart';

class ColorScreen extends StatelessWidget {
  final int id;
  const ColorScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ColoresBloc, ColoresState>(
      builder: (context, state) {
        if (state.isLoading) return const FullScreenLoader();
        final color = state.colores.where((e) => e.id == id).firstOrNull ??
            const ColorItem(id: 0, nombre: '');
        return BlocProvider(
          create: (ctx) => ColorFormCubit(
            onCreateCallback: ctx.read<ColoresBloc>().createColor,
            onUpdateCallback: ctx.read<ColoresBloc>().updateColor,
            onDeleteCallback: ctx.read<ColoresBloc>().deleteColor,
            color: color,
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Screen1(
              backRoute: true,
              widget: [_form(context)],
              title: color.id == 0 ? 'Crear Color' : 'Editar Color',
              isGridview: false,
            ),
          ),
        );
      },
    );
  }

  Widget _form(BuildContext context) {
    return BlocBuilder<ColorFormCubit, ColorFormState>(
      builder: (context, form) {
        final cubit = context.read<ColorFormCubit>();
        final hexValido = ColorFormCubit.normalizarHex(form.hex);
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
                    label: 'Hex (ej: C0392B)',
                    initialValue: form.hex,
                    onChanged: cubit.onHexChanged,
                    errorMessage: form.hex.isNotEmpty && hexValido == null
                        ? 'Hex inválido'
                        : null,
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                      color: hexValido == null
                          ? Colors.transparent
                          : colorFromHex(hexValido),
                    ),
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
                          await cubit.onSubmit(isUpdate: form.id != 0);
                      if (context.mounted) showSnackbarBool(context, value);
                    },
                    texto: form.id == 0 ? 'Guardar' : 'Modificar',
                  ),
                  if (form.id != 0) ...[
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
            ],
          ),
        );
      },
    );
  }
}
