import 'package:flutter/material.dart';

/// Visor cuadrado y centrado de una imagen del padrón, con zoom.
///
/// Se abre como diálogo y no como pantalla nueva para que la ficha quede
/// visible detrás: mirar la foto no es cambiar de contexto.
class VisorImagen extends StatefulWidget {
  const VisorImagen({
    super.key,
    required this.url,
    required this.titulo,
    this.subtitulo,
    this.alDescargar,
    this.alEditar,
    this.giros = 0,
  });

  final String url;
  final String titulo;
  final String? subtitulo;
  final Future<void> Function()? alDescargar;
  final VoidCallback? alEditar;
  final int giros;

  static Future<void> mostrar(
    BuildContext context, {
    required String url,
    required String titulo,
    String? subtitulo,
    Future<void> Function()? alDescargar,
    Future<void> Function()? alEditar,
    int giros = 0,
  }) async {
    final editar = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x996D7470),
      builder: (contextoVisor) => VisorImagen(
        url: url,
        titulo: titulo,
        subtitulo: subtitulo,
        alDescargar: alDescargar,
        alEditar: alEditar == null
            ? null
            : () => Navigator.of(contextoVisor).pop(true),
        giros: giros,
      ),
    );
    if (editar == true && alEditar != null && context.mounted) {
      await alEditar();
    }
  }

  @override
  State<VisorImagen> createState() => _VisorImagenState();
}

class _VisorImagenState extends State<VisorImagen> {
  bool _descargando = false;

  Future<void> _descargar() async {
    final accion = widget.alDescargar;
    if (accion == null || _descargando) return;
    setState(() => _descargando = true);
    try {
      await accion();
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    const fondoVisor = Color(0xFFADB3B0);
    const textoOscuro = Color(0xFF1B211D);

    return LayoutBuilder(
      builder: (context, limites) {
        final lado = (limites.biggest.shortestSide - 32).clamp(0.0, 640.0);
        return Dialog(
          constraints: const BoxConstraints(minWidth: 0),
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: fondoVisor,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          child: SizedBox.square(
            key: const ValueKey('visor-fotografia-cuadrado'),
            dimension: lado,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.titulo,
                              style: tema.textTheme.titleMedium?.copyWith(
                                color: textoOscuro,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.subtitulo != null)
                              Text(
                                widget.subtitulo!,
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: textoOscuro.withValues(alpha: .7),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.alEditar != null)
                        IconButton(
                          tooltip: 'Editar fotografía',
                          onPressed: _descargando ? null : widget.alEditar,
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: textoOscuro,
                          ),
                        ),
                      if (widget.alDescargar != null)
                        IconButton(
                          tooltip: 'Descargar fotografía',
                          onPressed: _descargando ? null : _descargar,
                          icon: _descargando
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.download_outlined,
                                  color: textoOscuro,
                                ),
                        ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: textoOscuro),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColoredBox(
                        color: fondoVisor,
                        child: Center(
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 5,
                            child: RotatedBox(
                              quarterTurns: widget.giros,
                              child: Image.network(
                                widget.url,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, hijo, progreso) =>
                                    progreso == null
                                    ? CustomPaint(
                                        painter: const _FondoTransparencia(),
                                        child: hijo,
                                      )
                                    : const SizedBox(
                                        height: 240,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                errorBuilder: (context, error, _) => Container(
                                  padding: const EdgeInsets.all(32),
                                  color: fondoVisor,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.broken_image_outlined,
                                        size: 40,
                                        color: tema.colorScheme.error,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'No se pudo cargar la imagen.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Arrastrá o pellizcá para acercar',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: textoOscuro.withValues(alpha: .6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// El damero permite ver los píxeles transparentes sin alterar el PNG.
class _FondoTransparencia extends CustomPainter {
  const _FondoTransparencia();

  @override
  void paint(Canvas canvas, Size size) {
    const lado = 16.0;
    final claro = Paint()..color = const Color(0xFFE2E2E2);
    final gris = Paint()..color = const Color(0xFFC5C5C5);
    canvas.drawRect(Offset.zero & size, claro);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var fila = 0; fila * lado < size.height; fila++) {
      for (var columna = 0; columna * lado < size.width; columna++) {
        if ((fila + columna).isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(columna * lado, fila * lado, lado, lado),
            gris,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FondoTransparencia oldDelegate) => false;
}
