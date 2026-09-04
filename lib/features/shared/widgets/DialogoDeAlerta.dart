// ignore_for_file: file_names, unused_element

import 'package:flutter/material.dart';

void dialogoDeAlerta(
  BuildContext context,
  Function onPressed, {
  String titulo = 'Confirmar Eliminación',
  String mensaje = '¿Está seguro de que desea eliminar este elemento?',
  String textoConfirmar = 'Eliminar',
}) {
    showDialog(
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
    );
  }