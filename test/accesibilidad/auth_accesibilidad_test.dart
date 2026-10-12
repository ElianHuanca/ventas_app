import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:textiles_app/features/auth/auth.dart';

import '../helpers/fake_repositories.dart';
import 'accesibilidad_helpers.dart';

void main() {
  Future<void> montar(WidgetTester tester) => montarPantalla(
        tester,
        BlocProvider(
          create: (_) => LoginFormCubit(authRepository: FakeAuthRepository()),
          child: const LoginScreen(),
        ),
      );

  group('/login (LoginScreen)', () {
    verificarGuias('vacía', montar);

    verificarGuias('con email y contraseña', (tester) async {
      await montar(tester);
      await tester.enterText(
          find.byKey(const Key('login_email')), FakeAuthRepository.emailOk);
      await tester.enterText(find.byKey(const Key('login_password')),
          FakeAuthRepository.passwordOk);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    });
  });
}
