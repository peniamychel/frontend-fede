import 'package:flutter/material.dart';

/// Visor a pantalla completa de una imagen del padrón, con zoom.
///
/// Se abre como diálogo y no como pantalla nueva para que la ficha quede
/// visible detrás: mirar la foto no es cambiar de contexto.
class VisorImagen extends StatelessWidget {
  const VisorImagen({
    super.key,
    required this.url,
    required this.titulo,
    this.subtitulo,
  });

  final String url;
  final String titulo;
  final String? subtitulo;

  static Future<void> mostrar(
    BuildContext context, {
    required String url,
    required String titulo,
    String? subtitulo,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) =>
          VisorImagen(url: url, titulo: titulo, subtitulo: subtitulo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: tema.textTheme.titleMedium
                            ?.copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (subtitulo != null)
                      Text(subtitulo!,
                          style: tema.textTheme.bodySmall
                              ?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, hijo, progreso) => progreso == null
                      ? hijo
                      : const SizedBox(
                          height: 240,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white)),
                        ),
                  errorBuilder: (context, error, _) => Container(
                    padding: const EdgeInsets.all(32),
                    color: tema.colorScheme.surface,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            size: 40, color: tema.colorScheme.error),
                        const SizedBox(height: 8),
                        const Text('No se pudo cargar la imagen.'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Arrastrá o pellizcá para acercar',
              style: tema.textTheme.bodySmall?.copyWith(color: Colors.white54)),
        ],
      ),
    );
  }
}
