import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../../domain/domain.dart';
import '../bloc/bloc.dart';
import '../widgets/data_table_apliques.dart';

class VentaApliquesScreen extends StatelessWidget {
  final TextEditingController cantidadController = TextEditingController();
  final TextEditingController precioController = TextEditingController();

  VentaApliquesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen1(
      widget: _widget(context),
      title: 'Venta de Apliques',
      isGridview: false,
      backRoute: true,
    );
  }

  List<Widget> _widget(BuildContext context) {
    final apliquesState = context.watch<ApliquesBloc>().state;
    final formState = context.watch<VentaApliquesFormCubit>().state;
    final formCubit = context.read<VentaApliquesFormCubit>();

    final coloresDisponibles = apliquesState.stock
        .where((e) => e.apliqueId == formState.idapliques)
        .toList();

    final descuento = double.tryParse(formState.descuento) ?? 0;
    final totalPagar = formState.total - descuento;

    return [
      apliquesState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: DropdownMenu<Aplique>(
                          width: MediaQuery.of(context).size.width * 0.93,
                          hintText: 'Seleccione un Aplique',
                          onSelected: formCubit.onApliqueChanged,
                          dropdownMenuEntries: apliquesState.apliques
                              .map<DropdownMenuEntry<Aplique>>((e) {
                            return DropdownMenuEntry<Aplique>(
                              value: e,
                              label: e.nombre,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: DropdownMenu<StockAplique>(
                          // La key reinicia la selección visible al cambiar de aplique
                          key: ValueKey(formState.idapliques),
                          width: MediaQuery.of(context).size.width * 0.93,
                          hintText: 'Seleccione un Color',
                          enabled: formState.idapliques != 0,
                          onSelected: formCubit.onColorChanged,
                          dropdownMenuEntries: coloresDisponibles
                              .map<DropdownMenuEntry<StockAplique>>((e) {
                            final texto =
                                '${e.colorNombre} (stock: ${e.stock})';
                            return DropdownMenuEntry<StockAplique>(
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
                      ),
                    ],
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
                            onChanged: formCubit.onCantidadChanged,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                              suffixText: 'uds',
                              suffixStyle: TextStyle(fontSize: 12),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.9,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: TextFormField(
                            controller: precioController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: formCubit.onPrecioChanged,
                            decoration: const InputDecoration(
                              labelText: 'Precio',
                              suffixText: 'Bs',
                              suffixStyle: TextStyle(fontSize: 12),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
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
                      final error = formCubit.addDetalle();
                      if (error != null) {
                        showSnackbar(context, error);
                        return;
                      }
                      cantidadController.clear();
                      precioController.clear();
                    },
                    texto: 'Añadir',
                  ),
                ],
              ),
            ),
      const Divider(thickness: 1),
      DataTableApliques(
        listbody: formState.detalles,
        total: formState.total,
        onTap: (int idapliques, int idcolor, double cantidad, double precio) {
          formCubit.removeDetalle(idapliques, idcolor, cantidad, precio);
        },
      ),
      Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: TextFormField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: formCubit.onDescuentoChanged,
          decoration: const InputDecoration(
            labelText: 'Descuento',
            suffixText: 'Bs',
            suffixStyle: TextStyle(fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
        ),
      ),
      Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total a pagar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '$totalPagar Bs',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(12.0),
        child: MaterialButtonWidget(
          onTap: () {
            if (formCubit.state.detalles.isEmpty) {
              showSnackbar(context, 'Agregue al menos un aplique a la venta');
              return;
            }
            dialogoDeAlerta(
              context,
              () async {
                final value = await formCubit.onFormSubmit();
                if (context.mounted) showSnackbarBool(context, value);
              },
              titulo: 'Confirmar Venta',
              mensaje: '¿Está seguro de registrar esta venta de apliques?',
              textoConfirmar: 'Confirmar',
            );
          },
          texto: 'Guardar',
        ),
      ),
    ];
  }
}
