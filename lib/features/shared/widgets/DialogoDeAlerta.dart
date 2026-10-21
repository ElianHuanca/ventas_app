// ignore_for_file: file_names, unused_element

import 'dart:async';

import 'package:flutter/material.dart';

void dialogoDeAlerta(
  BuildContext context,
  VoidCallback onPressed, {
  String titulo = 'Confirmar Eliminación',
  String mensaje = '¿Está seguro de que desea eliminar este elemento?',
  String textoConfirmar = 'Eliminar',
}) {
  // No se espera a que se cierre: la acción va en el botón de confirmar
  unawaited(showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onPressed();
            },
            child: Text(textoConfirmar),
          ),
        ],
      );
    },
  ));
}
