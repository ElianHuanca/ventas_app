import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/auth.dart';

void main() {
  group('SesionListenable', () {
    late StreamController<bool> cambios;

    setUp(() => cambios = StreamController<bool>.broadcast());
    tearDown(() => cambios.close());

    test('avisa al router en cada entrada y salida de sesión', () async {
      final listenable = SesionListenable(cambios.stream);
      addTearDown(listenable.dispose);
      var avisos = 0;
      listenable.addListener(() => avisos++);

      cambios
        ..add(true)
        ..add(false);
      await Future<void>.delayed(Duration.zero);

      expect(avisos, 2);
    });

    test('después de dispose deja de escuchar el stream', () async {
      final listenable = SesionListenable(cambios.stream);
      var avisos = 0;
      listenable.addListener(() => avisos++);

      listenable.dispose();
      cambios.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(avisos, 0);
      expect(cambios.hasListener, isFalse);
    });
  });

  group('AuthFallo', () {
    test('toString es el mensaje listo para la UI', () {
      const fallo = AuthFallo('Email o contraseña incorrectos');

      expect(fallo.toString(), 'Email o contraseña incorrectos');
      expect('$fallo', fallo.mensaje);
    });
  });
}
