import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/apliques/infrastructure/infrastructure.dart';

void main() {
  Map<String, dynamic> fila(int aplique, int color, int stock) => {
        'aplique_id': aplique,
        'color_id': color,
        'stock': stock,
        'colores': {'nombre': 'c$color', 'hex': ''},
      };

  test('deja solo los colores vinculados a su aplique', () {
    final inventario = [fila(1, 10, 5), fila(1, 11, 3), fila(2, 10, 7)];
    final vinculos = [
      {'idaplique': 1, 'idcolor': 10},
      {'idaplique': 2, 'idcolor': 10},
    ];

    final resultado =
        ApliquesDatasourceImpl.soloColoresVinculados(inventario, vinculos);

    expect(resultado.map((e) => (e['aplique_id'], e['color_id'])),
        [(1, 10), (2, 10)]);
  });

  test('el vínculo es por aplique: el color de otro aplique no cuenta', () {
    final inventario = [fila(1, 10, 5)];
    final vinculos = [
      {'idaplique': 2, 'idcolor': 10},
    ];

    expect(ApliquesDatasourceImpl.soloColoresVinculados(inventario, vinculos),
        isEmpty);
  });

  test('sin vínculos no ofrece nada, aunque haya stock', () {
    expect(
        ApliquesDatasourceImpl.soloColoresVinculados([fila(1, 10, 5)], []),
        isEmpty);
  });
}
