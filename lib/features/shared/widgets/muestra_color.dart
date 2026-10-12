import 'package:flutter/material.dart';

import 'color_from_hex.dart';

/// Muestra redonda de un color, con borde para que los claros (Blanco, Crema)
/// se distingan del fondo de la pantalla.
class MuestraColor extends StatelessWidget {
  final String hex;
  final double radio;

  const MuestraColor({super.key, required this.hex, this.radio = 8});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26),
      ),
      child: CircleAvatar(radius: radio, backgroundColor: colorFromHex(hex)),
    );
  }
}
