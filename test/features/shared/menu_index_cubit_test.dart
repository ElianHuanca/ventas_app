import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/shared/widgets/menu_index_cubit.dart';

void main() {
  group('MenuIndexState', () {
    test('el índice por defecto es 0', () {
      expect(MenuIndexState().index, 0);
    });

    test('copyWith cambia el índice o conserva el actual', () {
      final estado = MenuIndexState(index: 3);

      expect(estado.copyWith(index: 5).index, 5);
      expect(estado.copyWith().index, 3);
    });
  });

  group('MenuIndexCubit', () {
    late MenuIndexCubit cubit;

    setUp(() => cubit = MenuIndexCubit());
    tearDown(() => cubit.close());

    test('arranca en la primera sección (índice 0)', () {
      expect(cubit.state.index, 0);
    });

    test('setIndex actualiza el índice', () {
      cubit.setIndex(4);
      expect(cubit.state.index, 4);

      cubit.setIndex(0);
      expect(cubit.state.index, 0);
    });

    test('setIndex emite un estado por cada cambio', () async {
      final emitidos = expectLater(
        cubit.stream.map((e) => e.index),
        emitsInOrder([2, 7]),
      );

      cubit
        ..setIndex(2)
        ..setIndex(7);

      await emitidos;
    });
  });
}
