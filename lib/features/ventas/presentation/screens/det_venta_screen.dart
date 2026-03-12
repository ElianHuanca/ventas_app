import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/shared/shared.dart';
import 'package:textiles_app/features/shared/widgets/data_table_telas.dart';
import 'package:textiles_app/features/telas/domain/domain.dart';
import 'package:textiles_app/features/telas/presentation/bloc/bloc.dart';
import 'package:textiles_app/features/ventas/domain/domain.dart';
import '../bloc/bloc.dart';

class DetVenta extends StatelessWidget {
  final int idventa;
  final TextEditingController precioController = TextEditingController();
  final TextEditingController cantidadController = TextEditingController();

  DetVenta({super.key, required this.idventa});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VentaBloc, VentaState>(
      builder: (context, ventaState) {
        if (ventaState.venta == null) {
          return const FullScreenLoader();
        }
        final venta = ventaState.venta!;
        return Screen1(
          widget: _widget(context, venta),
          title: 'Registro Ventas',
          isGridview: false,
          backRoute: true,
        );
      },
    );
  }

  List<Widget> _widget(BuildContext context, Venta venta) {
    final telasState = context.watch<TelasBloc>().state;
    final detalleVentaForm = context.watch<DetalleVentaFormCubit>().state;
    final detVentaFormCubit = context.read<DetalleVentaFormCubit>();

    return [
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
                          hintText: 'Seleccione un Producto',
                          onSelected: (value) {
                            detVentaFormCubit.onPrecxCompraChanged(
                                value?.precxcompra ?? 0);
                            detVentaFormCubit.onNombreChanged(value!.nombre);
                            detVentaFormCubit.onIdTelasChanged(value.id);
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
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        label: 'Precio',
                        onChanged: detVentaFormCubit.onPrecioChanged,
                        controller: precioController,
                      ),
                      MiTextField(
                        flex: 3,
                        keyboardType:
                            const TextInputType.numberWithOptions(
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
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
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
