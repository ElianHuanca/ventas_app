import 'package:flutter/material.dart';
import 'package:textiles_app/features/apliques/domain/entities/color_item.dart';
import 'color_from_hex.dart';

/// Lista de colores con switch para vincular/quitar colores de un producto
/// (tela o aplique). La baja es lógica (activo = false en la tabla puente).
class ProductoColoresList extends StatelessWidget {
  final bool isLoading;
  final List<ColorItem> colores;
  final void Function(int idcolor, bool vinculado) onToggle;

  const ProductoColoresList({
    super.key,
    required this.isLoading,
    required this.colores,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text('Colores', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ...colores.map((color) => SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  secondary: CircleAvatar(
                    radius: 8,
                    backgroundColor: colorFromHex(color.hex),
                  ),
                  title: Text(color.nombre),
                  value: color.vinculado,
                  onChanged: (valor) => onToggle(color.id, valor),
                )),
        ],
      ),
    );
  }
}
