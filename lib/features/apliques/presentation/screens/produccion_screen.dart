import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/sucursales/domain/domain.dart';
import 'package:textiles_app/features/sucursales/presentation/bloc/bloc.dart';
import '../../domain/domain.dart';
import '../bloc/bloc.dart';

class ProduccionScreen extends StatelessWidget {
  final TextEditingController cantidadController = TextEditingController();

  ProduccionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen1(
      widget: [_widget(context)],
      title: 'Fabricación',
      isGridview: false,
      backRoute: false,
    );
  }

  double _stockDe(ProduccionFormState state, int idcolor) {
    for (final e in state.stock) {
      if (e.apliqueId == state.idapliques && e.colorId == idcolor) {
        return e.stock;
      }
    }
    return 0;
  }

  Widget _widget(BuildContext context) {
    final sucursalesState = context.watch<SucursalesBloc>().state;
    final state = context.watch<ProduccionFormCubit>().state;
    final cubit = context.read<ProduccionFormCubit>();

    if (state.isLoading || sucursalesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/fabricacion/historial'),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Ver historial'),
            ),
          ),
          DropdownMenu<Sucursal>(
            width: MediaQuery.of(context).size.width * 0.93,
            hintText: 'Seleccione una Sucursal',
            onSelected: (value) => cubit.onSucursalChanged(value?.id ?? 0),
            dropdownMenuEntries: sucursalesState.sucursales
                .map<DropdownMenuEntry<Sucursal>>((e) =>
                    DropdownMenuEntry<Sucursal>(value: e, label: e.nombre))
                .toList(),
          ),
          const SizedBox(height: 15),
          DropdownMenu<Aplique>(
            width: MediaQuery.of(context).size.width * 0.93,
            hintText: 'Seleccione un Aplique',
            enabled: state.idsucursal != 0,
            onSelected: cubit.onApliqueChanged,
            dropdownMenuEntries: state.apliques
                .map<DropdownMenuEntry<Aplique>>(
                    (e) => DropdownMenuEntry<Aplique>(value: e, label: e.nombre))
                .toList(),
          ),
          const SizedBox(height: 15),
          DropdownMenu<ColorItem>(
            width: MediaQuery.of(context).size.width * 0.93,
            hintText: 'Seleccione un Color',
            enabled: state.idapliques != 0,
            onSelected: cubit.onColorChanged,
            dropdownMenuEntries: state.colores
                .map<DropdownMenuEntry<ColorItem>>((e) {
              final texto = '${e.nombre} (stock: ${_stockDe(state, e.id)})';
              return DropdownMenuEntry<ColorItem>(
                value: e,
                label: texto,
                labelWidget: Row(
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: colorFromHex(e.hex),
                    ),
                    const SizedBox(width: 8),
                    Text(texto),
                  ],
                ),
              );
            }).toList(),
          ),
          if (state.idcolor != 0) ...[
            const SizedBox(height: 8),
            Text(
              'Stock actual en esta sucursal: ${state.stockActual} uds',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: TextFormField(
                    controller: cantidadController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    onChanged: cubit.onCantidadChanged,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad fabricada',
                      suffixText: 'uds',
                      suffixStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          MaterialButtonWidget(
            onTap: () async {
              final error = await cubit.registrar();
              if (!context.mounted) return;
              if (error != null) {
                showSnackbar(context, error);
              } else {
                cantidadController.clear();
                showSnackbar(context, 'Producción registrada, stock actualizado');
              }
            },
            texto: 'Registrar producción',
          ),
        ],
      ),
    );
  }
}
