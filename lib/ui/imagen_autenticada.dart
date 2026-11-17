import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/api_config.dart';
import 'padron_scope.dart';

/// Las imágenes privadas se descargan por la API con Authorization, también en web.
/// Nunca se añade el token a la URL ni se usa un <img> público como alternativa.
class ImagenAutenticada extends StatefulWidget {
  const ImagenAutenticada(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
    this.gaplessPlayback = false,
    this.filterQuality = FilterQuality.medium,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final bool gaplessPlayback;
  final FilterQuality filterQuality;

  @override
  State<ImagenAutenticada> createState() => _ImagenAutenticadaState();
}

class _ImagenAutenticadaState extends State<ImagenAutenticada> {
  Future<Uint8List>? _contenido;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _contenido ??= _descargar();
  }

  @override
  void didUpdateWidget(ImagenAutenticada oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _contenido = _descargar();
  }

  Future<Uint8List> _descargar() async {
    final descarga = await PadronScope.of(
      context,
    ).api.descargarUrl(Uri.parse(ApiConfig.urlAbsoluta(widget.url)));
    return Uint8List.fromList(descarga.bytes);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _contenido,
    builder: (context, estado) {
      if (estado.hasError) {
        return widget.errorBuilder?.call(
              context,
              estado.error!,
              estado.stackTrace,
            ) ??
            SizedBox(
              width: widget.width,
              height: widget.height,
              child: const Icon(Icons.broken_image_outlined),
            );
      }
      if (estado.connectionState != ConnectionState.done ||
          estado.data == null) {
        return widget.loadingBuilder?.call(
              context,
              const SizedBox.shrink(),
              const ImageChunkEvent(
                cumulativeBytesLoaded: 0,
                expectedTotalBytes: null,
              ),
            ) ??
            SizedBox(width: widget.width, height: widget.height);
      }
      final imagen = Image.memory(
        estado.data!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: widget.errorBuilder,
        gaplessPlayback: widget.gaplessPlayback,
        filterQuality: widget.filterQuality,
      );
      return widget.loadingBuilder?.call(context, imagen, null) ?? imagen;
    },
  );
}
