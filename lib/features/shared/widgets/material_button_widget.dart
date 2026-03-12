import 'package:flutter/material.dart';

class MaterialButtonWidget extends StatelessWidget {
  final VoidCallback onTap;
  final String texto;
  final Color? buttonColor;

  const MaterialButtonWidget({
    super.key,
    required this.onTap,
    required this.texto,
    this.buttonColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = buttonColor ?? _colorForText(texto);
    return MaterialButton(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      color: color,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 10),
            Text(
              texto,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }

  static Color _colorForText(String texto) {
    switch (texto) {
      case 'Guardando...':
        return Colors.grey;
      case 'Eliminar':
        return Colors.red;
      default:
        return Colors.black;
    }
  }
}
