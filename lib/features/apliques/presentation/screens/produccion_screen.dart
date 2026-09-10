import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
          DropdownMenu<Sucursal>(
            width: MediaQuery.of(context).size.width * 0.93,
            hintText: 'Seleccione una Sucursal',
            onSelected: (value) =>
                cubit.onSucursalChanged(value?.id ?? 0),
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
                .map<DropdownMenuEntry<ColorItem>>(
                    (e) => DropdownMenuEntry<ColorItem>(
                          value: e,
                          label: e.nombre,
                          labelWidget: Row(
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundColor: colorFromHex(e.hex),
                              ),
                              const SizedBox(width: 8),
                              Text(e.nombre),
                            ],
                          ),
                        ))
                .toList(),
          ),
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
          const SizedBox(height: 15),
          const Divider(thickness: 1),
          Text('Producciones recientes',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          ...state.producciones.map((p) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: colorFromHex(p.hex),
                ),
                title: Text('${p.apliqueNombre} (${p.colorNombre})'),
                subtitle: Text('${p.sucursalNombre} · ${p.fecha}'),
                trailing: Text('${p.cantidad} uds'),
              )),
        ],
      ),
    );
  }
}
