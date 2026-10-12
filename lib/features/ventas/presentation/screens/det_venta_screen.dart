import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/shared/widgets/data_table_telas.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import '../bloc/bloc.dart';

class DetVenta extends StatelessWidget {
  final TextEditingController precioController = TextEditingController();
  final TextEditingController cantidadController = TextEditingController();

  DetVenta({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen1(
      widget: _widget(context),
      title: 'Registro Ventas',
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
      context.read<DetalleVentaFormCubit>().onFechaChanged(picked);
    }
  }

  List<Widget> _widget(BuildContext context) {
    final telasState = context.watch<TelasBloc>().state;
    final detalleVentaForm = context.watch<DetalleVentaFormCubit>().state;
    final detVentaFormCubit = context.read<DetalleVentaFormCubit>();

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: InkWell(
          onTap: () => _selectFecha(context, detalleVentaForm.fecha),
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
              '${detalleVentaForm.fecha.day.toString().padLeft(2, '0')}/'
              '${detalleVentaForm.fecha.month.toString().padLeft(2, '0')}/'
              '${detalleVentaForm.fecha.year}',
            ),
          ),
        ),
      ),
      telasState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        flex: 1,
                        child: DropdownMenu<Tela>(
                          width: MediaQuery.of(context).size.width * 0.93,
                          hintText: 'Seleccione una Tela',
                          // En escritorio se puede escribir: un texto que no es
                          // ninguna tela llega como null y limpia la selección
                          // (agregar sin tela queda bloqueado por idtelas == 0)
                          onSelected: (value) {
                            detVentaFormCubit
                                .onPrecxCompraChanged(value?.precxcompra ?? 0);
                            detVentaFormCubit
                                .onNombreChanged(value?.nombre ?? '');
                            detVentaFormCubit.onIdTelasChanged(value?.id ?? 0);
                          },
                          dropdownMenuEntries: telasState.telas
                              .map<DropdownMenuEntry<Tela>>((e) {
                            return DropdownMenuEntry<Tela>(
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
                      MiTextField(
                        flex: 3,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        label: 'Precio',
                        onChanged: detVentaFormCubit.onPrecioChanged,
                        controller: precioController,
                      ),
                      MiTextField(
                        flex: 3,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        label: 'Cantidad',
                        onChanged: detVentaFormCubit.onCantidadChanged,
                        controller: cantidadController,
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  MaterialButtonWidget(
                    onTap: () {
                      detVentaFormCubit.addDetalleVenta();
                      cantidadController.clear();
                      precioController.clear();
                    },
                    texto: 'Añadir',
                  ),
                ],
              ),
            ),
      const Divider(thickness: 1),
      DataTableMapTelas(
        listheader: const ['Nombre', 'Cantidad', 'Precio', 'Total', ''],
        listbody: detalleVentaForm.detVentas,
        total: detalleVentaForm.total,
        onTap: (int idtelas, double cantidad, double precio) {
          detVentaFormCubit.removeDetalleVenta(idtelas, cantidad, precio);
        },
      ),
      Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: TextFormField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: detVentaFormCubit.onDescuentoChanged,
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
        padding: const EdgeInsets.all(12.0),
        child: MaterialButtonWidget(
          onTap: () async {
            final value = await detVentaFormCubit.onFormSubmit();
            if (context.mounted) showSnackbarBool(context, value);
          },
          texto: 'Guardar',
        ),
      ),
    ];
  }
}
