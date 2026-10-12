import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:textiles_app/features/auth/presentation/bloc/login_form_cubit.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textStyles = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      // Tocar fuera solo cierra el teclado: no es un control para TalkBack
      excludeFromSemantics: true,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.storefront_rounded, size: 64),
                    const SizedBox(height: 12),
                    Text('Huantex',
                        textAlign: TextAlign.center,
                        style: textStyles.headlineSmall),
                    const SizedBox(height: 4),
                    Text('Inicia sesión para continuar',
                        textAlign: TextAlign.center,
                        style: textStyles.bodyMedium),
                    const SizedBox(height: 32),
                    const _LoginForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  bool _ocultarPassword = true;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LoginFormCubit>();
    final state = context.watch<LoginFormCubit>().state;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('login_email'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enabled: !state.enviando,
            onChanged: cubit.onEmailChanged,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('login_password'),
            obscureText: _ocultarPassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            enabled: !state.enviando,
            onChanged: cubit.onPasswordChanged,
            onSubmitted: (_) => cubit.onSubmit(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _ocultarPassword ? 'Mostrar' : 'Ocultar',
                icon: Icon(_ocultarPassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _ocultarPassword = !_ocultarPassword),
              ),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(
              state.error!,
              key: const Key('login_error'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('login_submit'),
            onPressed: state.puedeEnviar ? cubit.onSubmit : null,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: state.enviando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ingresar'),
          ),
        ],
      ),
    );
  }
}
