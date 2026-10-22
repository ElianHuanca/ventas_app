import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:textiles_app/features/shared/shared.dart';
import '../../domain/domain.dart';
import '../bloc/bloc.dart';

class ApliquesScreen extends StatefulWidget {
  const ApliquesScreen({super.key});

  @override
  State<ApliquesScreen> createState() => _ApliquesScreenState();
}

class _ApliquesScreenState extends State<ApliquesScreen> {
  // Controller propio: el TextField se destruye mientras el FullScreenLoader
  // tapa la recarga y, sin él, volvía vacío mientras la lista seguía filtrada
  final _buscador = TextEditingController();

  String get _busqueda => _buscador.text;

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ApliquesBloc, ApliquesState>(
      builder: (context, state) {
        return state.isLoading
            ? const FullScreenLoader()
            : Screen1(
                backRoute: false,
                widget: _buildBody(context, state),
                title: 'Apliques',
                isGridview: false,
                tooltipAgregar: 'Agregar aplique',
                onTap: () async {
                  await context.push('/aplique/0');
                  if (context.mounted) {
                    context.read<ApliquesBloc>().add(ApliquesLoadRequested());
                  }
                },
              );
      },
    );
  }

  List<Widget> _buildBody(BuildContext context, ApliquesState state) {
    final filtrados = state.apliques
        .where((a) => a.nombre.toLowerCase().contains(_busqueda.toLowerCase()))
        .toList();

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          controller: _buscador,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar aplique...',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      if (state.apliques.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No hay apliques registrados')),
        )
      else if (filtrados.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Sin resultados para esa búsqueda')),
        )
      else
        ...filtrados.map((aplique) => _apliqueCard(aplique, context)),
    ];
  }

  Widget _apliqueCard(Aplique aplique, BuildContext context) {
    // Los nombres vienen como "Flor Petalo Suizo Grande - Bolsa x100 und":
    // el sufijo tras " - " se muestra como chip aparte.
    final partes = aplique.nombre.split(' - ');
    final nombre = partes.first;
    final presentacion =
        partes.length > 1 ? partes.sublist(1).join(' - ') : null;

    Future<void> modificar() async {
      await context.push('/aplique/${aplique.id}');
      if (context.mounted) {
        context.read<ApliquesBloc>().add(ApliquesLoadRequested());
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: aplique.activo ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 3),
            color: Theme.of(context).primaryColor.withValues(alpha: .15),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      // Tocar la tarjeta abre Modificar (el lápiz es el mismo atajo, con su
      // etiqueta para TalkBack)
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: modificar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: aplique.activo
                          ? Theme.of(context).primaryColor
                          : Colors.black26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              aplique.activo ? Colors.black87 : Colors.black38,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Modificar',
                      onPressed: modificar,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                // Los chips van debajo, con todo el ancho (al lado del lápiz
                // quedaban de a uno por línea con letra grande)
                Padding(
                  padding: const EdgeInsets.only(left: 36, right: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip(_dimensiones(aplique), Icons.straighten),
                      _chip('${aplique.costoFabricacion} Bs',
                          Icons.precision_manufacturing_rounded),
                      if (presentacion != null)
                        _chip(presentacion, Icons.inventory_2_outlined),
                      if (!aplique.activo)
                        _chip('Inactivo', Icons.visibility_off),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Dos botones entran en una línea aun con letra grande
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/aplique-colores/${aplique.id}'),
                          icon: const Icon(Icons.palette_outlined, size: 16),
                          label: const Text('Colores'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/aplique-fotos/${aplique.id}'),
                          icon: const Icon(Icons.photo_library_outlined,
                              size: 16),
                          label: const Text('Fotos'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String texto, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.black45),
          const SizedBox(width: 4),
          Text(texto,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  String _dimensiones(Aplique aplique) {
    if (aplique.anchoCm == null && aplique.altoCm == null) {
      return 'Sin dimensiones';
    }
    final ancho = aplique.anchoCm?.toString() ?? '?';
    final alto = aplique.altoCm?.toString() ?? '?';
    return '$ancho × $alto cm';
  }
}
