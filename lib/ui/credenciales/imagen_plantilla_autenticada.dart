import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api_config.dart';
import '../padron_scope.dart';

/// Descarga las plantillas privadas con la sesión de la API, sin tokens en URL.
/// La descarga se conserva mientras la URL (incluida su versión) no cambie.
class ImagenPlantillaAutenticada extends StatefulWidget {
  const ImagenPlantillaAutenticada({super.key, required this.url});

  final String url;

  @override
  State<ImagenPlantillaAutenticada> createState() =>
      _ImagenPlantillaAutenticadaState();
}

class _ImagenPlantillaAutenticadaState
    extends State<ImagenPlantillaAutenticada> {
  late Future<Uint8List> _contenido;

  @override
  void initState() {
    super.initState();
    _contenido = _descargar();
  }

  @override
  void didUpdateWidget(ImagenPlantillaAutenticada oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _contenido = _descargar();
  }

  Future<Uint8List> _descargar() async {
    final descarga = await PadronScope.of(
      context,
    ).api.descargarUrl(Uri.parse(ApiConfig.urlAbsoluta(widget.url)));
    return Uint8List.fromList(descarga.bytes);
  }

  Widget _fallo() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_outlined),
        TextButton(
          onPressed: () {
            final contenido = _descargar();
            setState(() {
              _contenido = contenido;
            });
          },
          child: const Text('Reintentar plantilla'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: FutureBuilder<Uint8List>(
      future: _contenido,
      builder: (context, estado) {
        if (estado.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (estado.hasError || estado.data == null) return _fallo();
        return Image.memory(
          estado.data!,
          fit: BoxFit.fill,
          errorBuilder: (_, _, _) => _fallo(),
        );
      },
    ),
  );
}
