import 'package:flutter/material.dart';
import 'package:textiles_app/features/shared/shared.dart';

class DataTableProduccion extends StatelessWidget {
  final List<Map<String, dynamic>> listbody;
  final void Function(int, int, double) onTap;

  const DataTableProduccion({
    super.key,
    required this.listbody,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columnSpacing: 8,
      // La fila crece con el nombre: los de producción ocupan hasta 3 líneas
      // y con el alto fijo de 48 px la última salía cortada
      dataRowMaxHeight: double.infinity,
      columns: const ['Aplique', 'Color', 'Cantidad', '']
          .map((header) => DataColumn(
                label: Text(
                  header,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ))
          .toList(),
      rows: listbody.map((data) {
        return DataRow(cells: <DataCell>[
          _cell('${data['apliqueNombre']}'),
          DataCell(Row(
            children: [
              MuestraColor(hex: '${data['hex']}'),
              const SizedBox(width: 6),
              // Nombres largos: cortar con … en vez de desbordar la celda
              Flexible(
                child: Text('${data['colorNombre']}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black)),
              ),
            ],
          )),
          _cell('${data['cantidad']} uds'),
          DataCell(
            IconButton(
              tooltip: 'Quitar línea',
              padding: EdgeInsets.zero,
              onPressed: () => onTap(
                data['idaplique'] as int,
                data['idcolor'] as int,
                (data['cantidad'] as num).toDouble(),
              ),
              iconSize: 20,
              icon: const Icon(Icons.delete_forever_rounded),
            ),
          ),
        ]);
      }).toList(),
    );
  }
}

DataCell _cell(String texto) => DataCell(
    Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black)));
