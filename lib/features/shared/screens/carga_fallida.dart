import 'package:flutter/material.dart';

import 'screen1.dart';

/// Lo que se muestra cuando no se pudo cargar el registro a ver o editar (p. ej.
/// sin conexión): lo dice y deja volver, en vez de reventar con un null.
class CargaFallida extends StatelessWidget {
  final String titulo;

  const CargaFallida({super.key, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Screen1(
      widget: const [
        Padding(
          padding: EdgeInsets.fromLTRB(24, 60, 24, 0),
          child: Text(
            'No se pudo cargar. Revisá la conexión y volvé a intentar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      ],
      title: titulo,
      isGridview: false,
      backRoute: true,
    );
  }
}
