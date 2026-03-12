import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void showSnackbar(BuildContext context, String text) {
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  scaffoldMessenger.clearSnackBars();
  scaffoldMessenger.showSnackBar(
    SnackBar(content: Text(text)),
  );
}

void showSnackbarBool(
  BuildContext context,
  bool value, {
  bool popOnSuccess = true,
}) {
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  scaffoldMessenger.clearSnackBars();
  scaffoldMessenger.showSnackBar(
    SnackBar(
      content: Text(value ? 'Realizado correctamente' : 'Hubo un error'),
    ),
  );
  if (value && popOnSuccess && context.mounted && Navigator.canPop(context)) {
    context.pop();
  }
}
