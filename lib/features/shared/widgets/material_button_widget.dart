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
    final isEliminar = texto == 'Eliminar';
    final backgroundColor =
        isEliminar ? Colors.grey[50] : (buttonColor ?? Colors.black);
    final foregroundColor = isEliminar ? Colors.black : Colors.white;
    const side = BorderSide(color: Colors.black, width: 1.5);

    return MaterialButton(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: side,
      ),
      color: backgroundColor,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 10),
            Text(
              texto,
              style: TextStyle(color: foregroundColor, fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
