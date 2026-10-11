import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/sucursales/domain/entities/tela_sucursal.dart';

void main() {
  const lino = TelaSucursal(idtela: 3, nombre: 'Lino', disponible: true);

  test('copyWith cambia solo la disponibilidad (el toggle de la pantalla)', () {
    final apagada = lino.copyWith(disponible: false);

    expect(apagada.disponible, isFalse);
    expect(apagada.idtela, 3);
    expect(apagada.nombre, 'Lino');
    expect(lino.disponible, isTrue, reason: 'el original no cambia');
  });

  test('copyWith sin argumentos conserva la disponibilidad', () {
    expect(lino.copyWith().disponible, isTrue);
    expect(
        const TelaSucursal(idtela: 1, nombre: 'Seda', disponible: false)
            .copyWith()
            .disponible,
        isFalse);
  });
}
