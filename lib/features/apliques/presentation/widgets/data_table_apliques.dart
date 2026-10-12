import 'package:flutter/material.dart';

class DataTableApliques extends StatelessWidget {
  final List<Map<String, dynamic>> listbody;
  final double total;
  final void Function(int, int, double, double) onTap;

  const DataTableApliques({
    super.key,
    required this.listbody,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DataTable(
      columnSpacing: 8,
      // La fila crece con el nombre: los de producción ocupan hasta 3 líneas
      // y con el alto fijo de 48 px la última salía cortada
      dataRowMaxHeight: double.infinity,
      columns: const ['Nombre', 'Cantidad', 'Precio', 'Total', '']
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
      rows: [
        ...listbody.map((data) {
          return DataRow(cells: <DataCell>[
            _cell('${data['nombre']}'),
            _cell('${data['cantidad']}'),
            _cell('${data['precio']}Bs'),
            _cell('${data['total']}Bs'),
            DataCell(
              IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => onTap(
                  data['idapliques'] as int,
                  data['idcolor'] as int,
                  (data['cantidad'] as num).toDouble(),
                  (data['precio'] as num).toDouble(),
                ),
                iconSize: 20,
                icon: const Icon(Icons.delete_forever_rounded),
              ),
            ),
          ]);
        }).toList(),
        DataRow(cells: <DataCell>[
          _cell(''),
          _cell(''),
          const DataCell(Text('Total',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                  fontWeight: FontWeight.bold))),
          DataCell(Text('$total Bs',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                  fontWeight: FontWeight.bold))),
          _cell(''),
        ]),
      ],
    );
  }
}

DataCell _cell(String texto) => DataCell(
    Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black)));
