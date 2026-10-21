import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/clave_de_operacion.dart';

/// Un uuid v4 como lo acepta el tipo `uuid` de Postgres
final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

/// Devuelve siempre [valor]: deja ver dónde caen los bits de versión y
/// variante sobre bytes conocidos.
class _AzarFijo implements Random {
  _AzarFijo(this.valor);

  final int valor;

  @override
  int nextInt(int max) => valor % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  group('uuidV4', () {
    test('tiene el formato de un uuid v4 (versión 4, variante RFC)', () {
      for (var i = 0; i < 200; i++) {
        expect(uuidV4(), matches(_uuid));
      }
    });

    test('pisa solo los bits de versión y de variante', () {
      expect(uuidV4(_AzarFijo(0)), '00000000-0000-4000-8000-000000000000');
      expect(uuidV4(_AzarFijo(255)), 'ffffffff-ffff-4fff-bfff-ffffffffffff');
      expect(uuidV4(_AzarFijo(0xab)), 'abababab-abab-4bab-abab-abababababab');
    });

    test('con Random.secure no se repite', () {
      final claves = {for (var i = 0; i < 1000; i++) uuidV4()};
      expect(claves, hasLength(1000));
    });

    test('usa el Random que recibe (determinístico con semilla)', () {
      expect(uuidV4(Random(7)), uuidV4(Random(7)));
      expect(uuidV4(Random(7)), isNot(uuidV4(Random(8))));
    });
  });

  group('ClaveDeOperacion', () {
    late ClaveDeOperacion clave;

    setUp(() => clave = ClaveDeOperacion());

    Map<String, Object?> envio({
      double cantidad = 2,
      double descuento = 0,
      String dia = '2024-06-10',
    }) =>
        {
          'detalles': [
            {'idtelas': 1, 'cantidad': cantidad, 'precio': 100.0},
          ],
          'descuento': descuento,
          'dia': dia,
        };

    test('da un uuid v4', () {
      expect(clave.para(envio()), matches(_uuid));
    });

    test(
        'el mismo envío (aunque sean otros objetos con el mismo contenido) '
        'lleva la misma clave: es el reintento', () {
      final primera = clave.para(envio());

      expect(clave.para(envio()), primera);
      expect(clave.para(envio()), primera);
    });

    test('otro contenido es otro envío: otra clave', () {
      final primera = clave.para(envio());

      expect(clave.para(envio(cantidad: 3)), isNot(primera));
    });

    test('cambia cualquier parte: línea, descuento o día', () {
      final claves = [
        clave.para(envio()),
        clave.para(envio(cantidad: 3)),
        clave.para(envio(cantidad: 3, descuento: 1)),
        clave.para(envio(cantidad: 3, descuento: 1, dia: '2024-06-11')),
      ];

      expect(claves.toSet(), hasLength(4));
    });

    test('volver a un envío anterior después de otro no recupera su clave',
        () {
      final primera = clave.para(envio());
      clave.para(envio(cantidad: 3));

      expect(clave.para(envio()), isNot(primera));
    });

    test('después de descartar, el mismo envío lleva otra clave', () {
      final primera = clave.para(envio());
      clave.descartar();

      final segunda = clave.para(envio());

      expect(segunda, isNot(primera));
      expect(clave.para(envio()), segunda);
    });

    test('compara listas y mapas por contenido, en profundidad', () {
      List<Object?> base() => [
            {
              'a': [1, 2],
              'b': null,
            },
            'x',
          ];
      final primera = clave.para(base());
      expect(clave.para(base()), primera);

      // Cada una difiere de base() en una sola cosa
      final otras = <Object?>[
        [
          {
            'a': [1, 3],
            'b': null,
          },
          'x',
        ],
        [
          {
            'a': [1, 2, 3],
            'b': null,
          },
          'x',
        ],
        [
          {
            'a': [1, 2],
            'c': null, // otra clave con el mismo valor
          },
          'x',
        ],
        [
          {
            'a': [1, 2],
          },
          'x',
        ],
        [
          {
            'a': [1, 2],
            'b': null,
          },
        ],
        [
          {
            'a': [1, 2],
            'b': null,
          },
          'y',
        ],
        'x',
        null,
      ];
      for (final otra in otras) {
        final conBase = clave.para(base());
        expect(clave.para(otra), isNot(conBase), reason: '$otra');
      }
    });

    test('una clave nueva por cada ClaveDeOperacion', () {
      expect(ClaveDeOperacion().para(envio()),
          isNot(ClaveDeOperacion().para(envio())));
    });

    test('usa el Random que recibe', () {
      expect(ClaveDeOperacion(random: _AzarFijo(0)).para(envio()),
          '00000000-0000-4000-8000-000000000000');
    });
  });
}
