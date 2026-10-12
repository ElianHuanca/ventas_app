import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../../domain/domain.dart';
import '../bloc/bloc.dart';
import '../widgets/data_table_produccion.dart';

class ProduccionScreen extends StatelessWidget {
  final TextEditingController cantidadController = TextEditingController();

  ProduccionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen1(
      widget: [_widget(context)],
      title: 'Fabricación',
      isGridview: false,
      backRoute: true,
    );
  }

  Future<void> _selectFecha(BuildContext context, DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && context.mounted) {
      context.read<ProduccionFormCubit>().onFechaChanged(picked);
    }
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
    final state = context.watch<ProduccionFormCubit>().state;
    final cubit = context.read<ProduccionFormCubit>();

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: InkWell(
            onTap: () => _selectFecha(context, state.fecha),
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha',
                suffixIcon: Icon(Icons.calendar_today, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
              child: Text(
                '${state.fecha.day.toString().padLeft(2, '0')}/'
                '${state.fecha.month.toString().padLeft(2, '0')}/'
                '${state.fecha.year}',
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownMenu<Aplique>(
                width: MediaQuery.of(context).size.width * 0.93,
                hintText: 'Seleccione un Aplique',
                trailingIcon: const Icon(Icons.arrow_drop_down,
                    semanticLabel: 'Abrir lista de apliques'),
                selectedTrailingIcon: const Icon(Icons.arrow_drop_up,
                    semanticLabel: 'Cerrar lista de apliques'),
                onSelected: cubit.onApliqueChanged,
                dropdownMenuEntries: state.apliques
                    .map<DropdownMenuEntry<Aplique>>((e) =>
                        DropdownMenuEntry<Aplique>(value: e, label: e.nombre))
                    .toList(),
              ),
              const SizedBox(height: 15),
              DropdownMenu<ColorItem>(
                // La key reinicia la selección visible al cambiar de aplique
                key: ValueKey(state.idapliques),
                width: MediaQuery.of(context).size.width * 0.93,
                hintText: 'Seleccione un Color',
                trailingIcon: const Icon(Icons.arrow_drop_down,
                    semanticLabel: 'Abrir lista de colores'),
                selectedTrailingIcon: const Icon(Icons.arrow_drop_up,
                    semanticLabel: 'Cerrar lista de colores'),
                enabled: state.idapliques != 0,
                onSelected: cubit.onColorChanged,
                dropdownMenuEntries:
                    state.colores.map<DropdownMenuEntry<ColorItem>>((e) {
                  final texto = '${e.nombre} (stock: ${_stockDe(state, e.id)})';
                  return DropdownMenuEntry<ColorItem>(
                    value: e,
                    label: texto,
                    labelWidget: Row(
                      children: [
                        MuestraColor(hex: e.hex),
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
                onTap: () {
                  final error = cubit.addDetalleProduccion();
                  if (error != null) {
                    showSnackbar(context, error);
                  } else {
                    cantidadController.clear();
                  }
                },
                texto: 'Añadir',
              ),
            ],
          ),
        ),
        const Divider(thickness: 1),
        DataTableProduccion(
          listbody: state.detProducciones,
          onTap: cubit.removeDetalleProduccion,
        ),
        Container(
          padding: const EdgeInsets.all(12.0),
          child: MaterialButtonWidget(
            onTap: () async {
              final error = await cubit.onFormSubmit();
              if (!context.mounted) return;
              if (error != null) {
                showSnackbar(context, error);
              } else {
                showSnackbar(
                    context, 'Producción registrada, stock actualizado');
              }
            },
            texto: 'Guardar',
          ),
        ),
      ],
    );
  }
}
