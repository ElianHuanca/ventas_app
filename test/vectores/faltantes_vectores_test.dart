import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';

import 'vectores.dart';

/// `test/vectores/faltantes.json` con `mensajeFaltantes`,
/// `ordenParaFabricante`, `nombrePdfFaltantes`, `cantidadLegible` y el texto
/// que `pdfFaltantes` escribe en el PDF.
void main() {
  probarVectores('faltantes', (caso) async {
    final e = caso.entrada;
    if (e['tipo'] == 'cantidad_legible') {
      expect(cantidadLegible((e['cantidad'] as num).toDouble()), caso.esperado);
      return;
    }

    final sucursal = e['sucursal'] as String;
    final fecha = DateTime.parse(e['fecha'] as String);
    final faltantes = [
      for (final (i, f)
          in (e['faltantes'] as List).cast<Map<String, dynamic>>().indexed)
        Reposicion(
          item: StockConVentas(
            apliqueId: i + 1,
            aplique: f['aplique'] as String,
            colorId: i + 1,
            color: f['color'] as String,
            hex: f['hex'] as String,
            stock: (f['stock'] as num).toDouble(),
            vendidas: 0,
          ),
          estimada: false,
          porSemana: 0,
          minimo: 0,
          hacer: f['hacer'] as int,
        ),
    ];
    final esperado = caso.esperado! as Map<String, dynamic>;
    final pdf = esperado['pdf'] as Map<String, dynamic>;

    expect(
        mensajeFaltantes(
            sucursal: sucursal, fecha: fecha, faltantes: faltantes),
        esperado['mensaje']);
    expectComoVector([
      for (final r in ordenParaFabricante(faltantes))
        '${r.item.aplique}/${r.item.color}',
    ], esperado['orden_fabricante']);
    expect(nombrePdfFaltantes(sucursal: sucursal, fecha: fecha),
        pdf['nombre_archivo']);

    // El texto que quedó escrito en el PDF, palabra por palabra
    final palabras = _palabrasDelPdf(await pdfFaltantes(
        sucursal: sucursal, fecha: fecha, faltantes: faltantes));
    final tabla = _buscar(palabras, ['Aplique', 'Color', 'Quedan', 'Hacer']);
    expect(tabla, isNot(-1), reason: 'encabezado de la tabla en $palabras');
    expect(palabras.take(tabla).join(' '),
        endsWith(_normalizar('Sucursal: ${pdf['sucursal']} Fecha: ${pdf['dia']}')));
    final filas = (pdf['filas'] as List).cast<Map<String, dynamic>>();
    expect(
      palabras.skip(tabla + 4).join(' '),
      _normalizar([
        for (final f in filas) ...[
          f['aplique'],
          f['color'],
          f['quedan'],
          f['hacer']
        ],
        pdf['resumen'],
        pdf['total_texto'],
      ].join(' ')),
    );
  });
}

String _normalizar(String texto) =>
    texto.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).join(' ');

int _buscar(List<String> palabras, List<String> secuencia) {
  for (var i = 0; i + secuencia.length <= palabras.length; i++) {
    var coincide = true;
    for (var j = 0; j < secuencia.length && coincide; j++) {
      coincide = palabras[i + j] == secuencia[j];
    }
    if (coincide) return i;
  }
  return -1;
}

/// Las palabras que dibuja el PDF, en orden. El paquete `pdf` escribe cada
/// palabra con `[(texto)]TJ` en streams comprimidos con zlib, en Latin-1
/// (Helvetica): cada byte es un carácter.
List<String> _palabrasDelPdf(Uint8List pdf) {
  final crudo = String.fromCharCodes(pdf);
  final palabras = <String>[];
  for (final inicio in RegExp(r'stream\r?\n').allMatches(crudo)) {
    final fin = crudo.indexOf('endstream', inicio.end);
    if (fin == -1) continue;
    final List<int> datos;
    try {
      datos = zlib.decode(pdf.sublist(inicio.end, fin));
    } on FormatException {
      continue; // fuentes y otros streams que no son de contenido
    }
    final contenido = String.fromCharCodes(datos);
    for (final m
        in RegExp(r'\[\(((?:\\.|[^\\)])*)\)\]TJ').allMatches(contenido)) {
      palabras.add(m
          .group(1)!
          .replaceAllMapped(RegExp(r'\\([0-7]{1,3}|.)'), (e) {
        final c = e.group(1)!;
        return RegExp(r'^[0-7]+$').hasMatch(c)
            ? String.fromCharCode(int.parse(c, radix: 8))
            : c;
      }));
    }
  }
  return palabras;
}
