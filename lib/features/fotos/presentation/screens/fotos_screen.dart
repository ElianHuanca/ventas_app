import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:textiles_app/features/shared/shared.dart';

import '../../domain/domain.dart';
import '../bloc/fotos_cubit.dart';

/// Abre la galería o la cámara y devuelve la foto achicada (null si el
/// usuario no eligió nada). Se inyecta para los tests.
typedef ElegirFoto = Future<FotoElegida?> Function(ImageSource origen);

/// Hasta 1600 px por lado y JPEG al 80 %: unos 200-400 KB por foto, lejos
/// del límite de 5 MB del bucket.
Future<FotoElegida?> elegirFotoDelSistema(ImageSource origen) async {
  final archivo = await ImagePicker().pickImage(
    source: origen,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
  );
  if (archivo == null) return null;
  return FotoElegida(
    bytes: await archivo.readAsBytes(),
    extension: extensionDeFoto(archivo.name),
  );
}

/// `IMG_1.PNG` → `png`; lo que el bucket no acepta se sube como JPEG.
String extensionDeFoto(String nombre) {
  final punto = nombre.lastIndexOf('.');
  final extension = punto < 0 ? '' : nombre.substring(punto + 1).toLowerCase();
  return switch (extension) {
    'png' => 'png',
    'webp' => 'webp',
    _ => 'jpg',
  };
}

/// La cámara solo existe en el celular (en Windows image_picker no la tiene).
bool get hayCamara =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Fotos de una tela (`/tela-fotos/:idtela`) o un aplique
/// (`/aplique-fotos/:idaplique`): subir de la galería o la cámara y quitar.
class FotosScreen extends StatelessWidget {
  final ProductoConFotos producto;
  final ElegirFoto elegirFoto;
  final bool conCamara;

  /// Cómo se dibuja cada URL; las capturas usan imágenes en memoria.
  final ImageProvider Function(String url) imagen;

  FotosScreen({
    super.key,
    required this.producto,
    this.elegirFoto = elegirFotoDelSistema,
    bool? conCamara,
    this.imagen = _imagenDeRed,
  }) : conCamara = conCamara ?? hayCamara;

  static ImageProvider _imagenDeRed(String url) => NetworkImage(url);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FotosCubit, FotosState>(
      builder: (context, state) {
        final titulo = state.nombre.isNotEmpty
            ? state.nombre
            : producto == ProductoConFotos.tela
                ? 'Fotos de la tela'
                : 'Fotos del aplique';
        return Screen1(
          backRoute: true,
          title: titulo,
          isGridview: false,
          widget: [_cuerpo(context, state)],
        );
      },
    );
  }

  Widget _cuerpo(BuildContext context, FotosState state) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
        child: Column(
          children: [
            const Text(
              'No se pudieron cargar las fotos. Revisá la conexión.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.read<FotosCubit>().cargar(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.subiendo
                      ? null
                      : () => _agregar(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
              ),
              if (conCamara) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.subiendo
                        ? null
                        : () => _agregar(context, ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Cámara'),
                  ),
                ),
              ],
            ],
          ),
          if (state.subiendo) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 4),
            const Text('Subiendo foto…',
                style: TextStyle(color: Colors.black54)),
          ],
          const SizedBox(height: 16),
          if (state.fotos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Todavía no tiene fotos.\n'
                'La primera es la que se ve en la web.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final (i, foto) in state.fotos.indexed)
                  _Miniatura(
                    imagen: imagen(foto.url),
                    principal: i == 0,
                    onQuitar: () => _confirmarQuitar(context, foto),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _agregar(BuildContext context, ImageSource origen) async {
    final cubit = context.read<FotosCubit>();
    final FotoElegida? foto;
    try {
      foto = await elegirFoto(origen);
    } on Exception {
      // Permiso de cámara o galería negado
      if (context.mounted) showSnackbar(context, 'No se pudo abrir la foto');
      return;
    }
    if (foto == null) return;
    final subio = await cubit.subir(foto);
    if (!subio && context.mounted) {
      showSnackbar(context, 'No se pudo subir la foto. Revisá la conexión.');
    }
  }

  void _confirmarQuitar(BuildContext context, Foto foto) {
    final cubit = context.read<FotosCubit>();
    dialogoDeAlerta(
      context,
      () async {
        final quito = await cubit.quitar(foto.id);
        if (!quito && context.mounted) {
          showSnackbar(context, 'No se pudo quitar la foto');
        }
      },
      titulo: 'Quitar foto',
      mensaje: 'Deja de verse en la app y en la web.',
      textoConfirmar: 'Quitar',
    );
  }
}

class _Miniatura extends StatelessWidget {
  final ImageProvider imagen;
  final bool principal;
  final VoidCallback onQuitar;

  const _Miniatura({
    required this.imagen,
    required this.principal,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: colores.surfaceContainerHighest,
            child: Image(
              image: imagen,
              fit: BoxFit.cover,
              semanticLabel: principal ? 'Foto principal' : 'Foto',
              errorBuilder: (context, error, stack) => Icon(
                Icons.broken_image_outlined,
                color: colores.onSurfaceVariant,
              ),
            ),
          ),
          if (principal)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colores.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Principal',
                  style: TextStyle(color: colores.onPrimary, fontSize: 12),
                ),
              ),
            ),
          Positioned(
            right: 2,
            top: 2,
            child: IconButton.filledTonal(
              tooltip: 'Quitar foto',
              onPressed: onQuitar,
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
    );
  }
}
