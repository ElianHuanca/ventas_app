import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/domain/domain.dart';

Reposicion _faltante(String aplique, String color, int hacer,
        {String hex = '#C0392B'}) =>
    Reposicion(
      item: StockConVentas(
        apliqueId: aplique.hashCode,
        aplique: aplique,
        colorId: color.hashCode,
        color: color,
        hex: hex,
        stock: 0,
        vendidas: 0,
      ),
      estimada: false,
      porSemana: 0,
      minimo: 0,
      hacer: hacer,
    );

String _nombres(List<Reposicion> rs) =>
    rs.map((r) => '${r.item.aplique}/${r.item.color}').join(', ');

/// Páginas del PDF: los diccionarios no van comprimidos, solo los streams.
int _paginas(List<int> pdf) =>
    RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(pdf)).length;

void main() {
  group('ordenParaFabricante', () {
    test('por aplique A→Z y, dentro de cada uno, de más a menos', () {
      final orden = ordenParaFabricante([
        _faltante('Mariposa', 'Verde', 4),
        _faltante('Flor Grande', 'Rojo', 10),
        _faltante('Mariposa', 'Rosa', 12),
        _faltante('Flor Grande', 'Azul', 43),
      ]);

      expect(_nombres(orden),
          'Flor Grande/Azul, Flor Grande/Rojo, Mariposa/Rosa, Mariposa/Verde');
    });

    test('ignora mayúsculas y a igual cantidad ordena por color', () {
      final orden = ordenParaFabricante([
        _faltante('mariposa', 'verde', 5),
        _faltante('Flor', 'Rojo', 5),
        _faltante('Mariposa', 'azul', 5),
      ]);

      expect(_nombres(orden), 'Flor/Rojo, Mariposa/azul, mariposa/verde');
    });

    test('no modifica la lista recibida', () {
      final original = [_faltante('B', 'x', 1), _faltante('A', 'x', 1)];

      ordenParaFabricante(original);

      expect(_nombres(original), 'B/x, A/x');
    });
  });

  group('nombrePdfFaltantes', () {
    test('sucursal en minúsculas sin espacios y fecha ISO', () {
      expect(
        nombrePdfFaltantes(
            sucursal: 'Shopping Miami', fecha: DateTime(2026, 10, 5)),
        'faltantes_shopping_miami_2026-10-05.pdf',
      );
    });

    test('sin letras ni números usables queda "sucursal"', () {
      expect(nombrePdfFaltantes(sucursal: 'Ñ', fecha: DateTime(2026, 1, 9)),
          'faltantes_sucursal_2026-01-09.pdf');
    });
  });

  group('pdfFaltantes', () {
    test('arma un PDF de una página con pocos faltantes', () async {
      final pdf = await pdfFaltantes(
        sucursal: 'Ramada',
        fecha: DateTime(2026, 10, 5),
        faltantes: [
          _faltante('Flor Pequeña', 'Celeste', 10),
          _faltante('Flor Grande', 'Rojo', 43),
        ],
      );

      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
      expect(_paginas(pdf), 1);
    });

    test('una lista larga sigue en más páginas', () async {
      final pdf = await pdfFaltantes(
        sucursal: 'Ramada',
        fecha: DateTime(2026, 10, 5),
        faltantes: [
          for (var i = 0; i < 120; i++)
            _faltante('Aplique ${i ~/ 6}', 'C$i', i),
        ],
      );

      expect(_paginas(pdf), greaterThan(1));
    });

    test('un hex vacío o inválido no rompe el PDF', () async {
      final pdf = await pdfFaltantes(
        sucursal: 'Ramada',
        fecha: DateTime(2026, 10, 5),
        faltantes: [
          _faltante('Flor', 'Sin color', 3, hex: ''),
          _faltante('Flor', 'Raro', 2, hex: 'zzz'),
        ],
      );

      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    });

    test('un nombre con guion largo o emoji no rompe el PDF', () async {
      final pdf = await pdfFaltantes(
        sucursal: 'Ramada – Centro',
        fecha: DateTime(2026, 10, 5),
        faltantes: [_faltante('Flor “Grande” 🌸', 'Rojo—oscuro', 3)],
      );

      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    });

    test('sin faltantes igual arma el PDF (total 0)', () async {
      final pdf = await pdfFaltantes(
          sucursal: 'Ramada', fecha: DateTime(2026, 10, 5), faltantes: []);

      expect(_paginas(pdf), 1);
    });
  });

  test('latin1Pdf: deja tildes y ñ, cambia lo que Helvetica no dibuja', () {
    expect(latin1Pdf('Flor Pequeña Ñandú'), 'Flor Pequeña Ñandú');
    expect(latin1Pdf('Ramada – Centro'), 'Ramada - Centro');
    expect(latin1Pdf('“Flor” ‘x’…'), '"Flor" \'x\'...');
    expect(latin1Pdf('Flor 🌸'), 'Flor ?');
  });
}
