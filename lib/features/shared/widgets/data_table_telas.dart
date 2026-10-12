// ignore_for_file: must_be_immutable
import 'package:flutter/material.dart';
import 'tabla_desplazable.dart';

class DataTableMapTelas extends StatelessWidget {
  final List<Map<String, dynamic>> listbody;
  final List<String> listheader;
  final double total;
  final void Function(int, double, double) onTap;

  const DataTableMapTelas({
    super.key,
    required this.listbody,
    required this.listheader,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TablaDesplazable(
      child: DataTable(
        columns: _columns(context, listheader),
        columnSpacing: 8,
        rows: _rows(listbody, total, onTap),
      ),
    );
  }
}

List<DataColumn> _columns(BuildContext context, List<String> listheader) =>
    listheader.map((header) => _column(context, header)).toList();

DataColumn _column(BuildContext context, String texto) => DataColumn(
      label: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

List<DataRow> _rows(
  List<Map<String, dynamic>> listbody,
  double total,
  void Function(int, double, double) onTap,
) {
  return [
    ...listbody.map((data) {
      return DataRow(cells: <DataCell>[
        _cell('${data['nombre']}'),
        _cell('${data['cantidad']}mts'),
        _cell('${data['precio']}Bs'),
        _cell('${data['total']}Bs'),
        _cellButton(
            onTap,
            data['idtelas'] as int,
            (data['cantidad'] as num).toDouble(),
            (data['precio'] as num).toDouble()),
      ]);
    }).toList(),
    DataRow(cells: <DataCell>[
      _cell(''),
      _cell(''),
      const DataCell(Text('Total',
          style: TextStyle(
              fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold))),
      DataCell(Text('$total Bs',
          style: const TextStyle(
              fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold))),
      _cell(''),
    ]),
  ];
}

DataCell _cell(String texto) => DataCell(
    Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black)));

DataCell _cellButton(void Function(int, double, double) onTap, int idtelas,
        double cantidad, double precio) =>
    DataCell(
      IconButton(
        padding: EdgeInsets.zero,
        onPressed: () => onTap(idtelas, cantidad, precio),
        iconSize: 20,
        icon: const Icon(Icons.delete_forever_rounded),
      ),
    );
