import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'mensaje_faltantes.dart';
import 'reposicion.dart';

/// Orden para el fabricante ([ReglaReposicion.porAplique]), sin tocar la
/// lista recibida.
List<Reposicion> ordenParaFabricante(List<Reposicion> faltantes) =>
    [...faltantes]..sort(ReglaReposicion.porAplique);

/// Nombre del archivo: `faltantes_ramada_2026-10-05.pdf`.
String nombrePdfFaltantes({required String sucursal, required DateTime fecha}) {
  final slug = sucursal
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final dia = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
  return 'faltantes_${slug.isEmpty ? 'sucursal' : slug}_$dia.pdf';
}

/// PDF para mandarle al fabricante: una tabla agrupada por aplique (ver
/// [ordenParaFabricante]) con color, lo que queda y cuánto hacer.
Future<Uint8List> pdfFaltantes({
  required String sucursal,
  required DateTime fecha,
  required List<Reposicion> faltantes,
}) {
  final filas = ordenParaFabricante(faltantes);
  final total = filas.fold<int>(0, (suma, r) => suma + r.hacer);
  final apliques = filas.map((r) => r.item.aplique).toSet().length;
  final dia = '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

  const vino = PdfColor.fromInt(0xFF8B2942);
  const gris = PdfColor.fromInt(0xFF6B6B6B);
  const bordes = PdfColor.fromInt(0xFFDDDDDD);
  const fondoGrupo = PdfColor.fromInt(0xFFF6F1F2);

  final doc = pw.Document(
    title: latin1Pdf('Faltantes $sucursal $dia'),
    author: 'Huantex',
  );

  // Cada aplique alterna el fondo para que el grupo se lea de un vistazo
  var grupo = -1;
  String? anterior;
  final cuerpo = <pw.TableRow>[];
  for (final r in filas) {
    final nuevo = r.item.aplique != anterior;
    if (nuevo) grupo++;
    anterior = r.item.aplique;
    cuerpo.add(pw.TableRow(
      decoration: pw.BoxDecoration(
        color: grupo.isOdd ? fondoGrupo : null,
        border:
            nuevo ? const pw.Border(top: pw.BorderSide(color: bordes)) : null,
      ),
      children: [
        _celda(nuevo ? r.item.aplique : '', negrita: true),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Row(children: [
            _muestra(r.item.hex),
            pw.SizedBox(width: 6),
            pw.Expanded(child: pw.Text(latin1Pdf(r.item.color))),
          ]),
        ),
        _celda(cantidadLegible(r.item.stock),
            alineado: pw.Alignment.centerRight),
        _celda('${r.hacer}',
            negrita: true, alineado: pw.Alignment.centerRight, color: vino),
      ],
    ));
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    header: (context) => context.pageNumber == 1
        ? pw.SizedBox()
        : pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(latin1Pdf('Faltantes $sucursal - $dia'),
                style: const pw.TextStyle(color: gris, fontSize: 9)),
          ),
    footer: (context) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(color: gris, fontSize: 9)),
    ),
    build: (context) => [
      pw.Text('Huantex',
          style: pw.TextStyle(
              color: vino, fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 2),
      pw.Text('Faltantes de apliques', style: const pw.TextStyle(fontSize: 14)),
      pw.SizedBox(height: 10),
      pw.Row(children: [
        pw.Text('Sucursal: ', style: const pw.TextStyle(color: gris)),
        pw.Text(latin1Pdf(sucursal),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(width: 24),
        pw.Text('Fecha: ', style: const pw.TextStyle(color: gris)),
        pw.Text(dia, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ]),
      pw.SizedBox(height: 16),
      pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(3),
          2: pw.FlexColumnWidth(1.2),
          3: pw.FlexColumnWidth(1.2),
        },
        border: const pw.TableBorder(
          bottom: pw.BorderSide(color: bordes),
        ),
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: vino),
            children: [
              _celda('Aplique', negrita: true, color: PdfColors.white),
              _celda('Color', negrita: true, color: PdfColors.white),
              _celda('Quedan',
                  negrita: true,
                  color: PdfColors.white,
                  alineado: pw.Alignment.centerRight),
              _celda('Hacer',
                  negrita: true,
                  color: PdfColors.white,
                  alineado: pw.Alignment.centerRight),
            ],
          ),
          ...cuerpo,
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$apliques ${apliques == 1 ? 'aplique' : 'apliques'}, '
            '${filas.length} ${filas.length == 1 ? 'color' : 'colores'}',
            style: const pw.TextStyle(color: gris),
          ),
          pw.Text('Total a hacer: $total',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: vino)),
        ],
      ),
    ],
  ));
  return doc.save();
}

pw.Widget _celda(
  String texto, {
  bool negrita = false,
  PdfColor? color,
  pw.Alignment alineado = pw.Alignment.centerLeft,
}) =>
    pw.Container(
      alignment: alineado,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        latin1Pdf(texto),
        style: pw.TextStyle(
          color: color,
          fontWeight: negrita ? pw.FontWeight.bold : null,
        ),
      ),
    );

/// Círculo con el color; sin hex válido, un círculo vacío.
pw.Widget _muestra(String hex) {
  final valido = RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(hex);
  return pw.Container(
    width: 9,
    height: 9,
    decoration: pw.BoxDecoration(
      shape: pw.BoxShape.circle,
      color: valido ? PdfColor.fromHex(hex) : null,
      border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
    ),
  );
}

/// Helvetica (la fuente que trae el PDF, sin embeber nada) solo dibuja
/// Latin-1: tildes y ñ sí, pero un guion largo o un emoji en un nombre
/// cargado a mano rompería el PDF. Se cambian por su equivalente o "?".
String latin1Pdf(String texto) {
  const equivalentes = {
    '–': '-',
    '—': '-',
    '‘': "'",
    '’': "'",
    '“': '"',
    '”': '"',
    '…': '...',
  };
  final salida = StringBuffer();
  for (final rune in texto.runes) {
    final c = String.fromCharCode(rune);
    salida.write(rune <= 0xFF ? c : equivalentes[c] ?? '?');
  }
  return salida.toString();
}
