import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/infrastructure/repositories/auth_repository_impl.dart';

import 'vectores.dart';

/// `test/vectores/auth_errores.json` con `AuthRepositoryImpl.mensajeDeError`.
void main() {
  probarVectores('auth_errores', (caso) {
    expect(AuthRepositoryImpl.mensajeDeError(caso.entrada['mensaje'] as String),
        caso.esperado);
  });
}
