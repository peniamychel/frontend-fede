import '../imagen_autenticada.dart';
import 'package:flutter/material.dart';
import '../../models/imagen.dart';
import '../../models/auditoria.dart';

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
    this.detalles,
  });

  final String url;
  final String titulo;
  final String? subtitulo;
  final Future<void> Function()? alDescargar;
  final VoidCallback? alEditar;
  final int giros;
  final Imagen? detalles;

  static Future<void> mostrar(
    BuildContext context, {
    required String url,
    required String titulo,
    String? subtitulo,
    Future<void> Function()? alDescargar,
    Future<void> Function()? alEditar,
    int giros = 0,
    Imagen? detalles,
  }) async {
    final editar = await showDialog<bool>(
      context: context,
      builder: (contextoVisor) => VisorImagen(
        url: url,
        titulo: titulo,
        subtitulo: subtitulo,
        alDescargar: alDescargar,
        alEditar: alEditar == null
            ? null
            : () => Navigator.of(contextoVisor).pop(true),
        giros: giros,
        detalles: detalles,
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
    final fondoVisor =
        DialogTheme.of(context).backgroundColor ??
        tema.colorScheme.surfaceContainerHigh;
    final texto = tema.colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, limites) {
        final lado = (limites.biggest.shortestSide - 32).clamp(0.0, 640.0);
        final conDetalles = widget.detalles != null;
        final horizontal =
            conDetalles && limites.maxHeight < 500 && limites.maxWidth >= 600;
        final ancho = conDetalles
            ? (limites.maxWidth - 32).clamp(0.0, horizontal ? 900.0 : 640.0)
            : lado;
        final alto = conDetalles
            ? (horizontal ? limites.maxHeight - 32 : ancho + 220).clamp(
                0.0,
                (limites.maxHeight - 32).clamp(0.0, 780.0),
              )
            : lado;
        return Dialog(
          constraints: const BoxConstraints(minWidth: 0),
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: fondoVisor,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          child: SizedBox(
            key: const ValueKey('visor-fotografia-cuadrado'),
            width: ancho,
            height: alto,
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
                                color: texto,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.subtitulo != null)
                              Text(
                                widget.subtitulo!,
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: tema.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      if (widget.alEditar != null)
                        IconButton(
                          tooltip: 'Editar fotografía',
                          onPressed: _descargando ? null : widget.alEditar,
                          icon: Icon(Icons.edit_outlined, color: texto),
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
                              : Icon(Icons.download_outlined, color: texto),
                        ),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: texto),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _conDetalles(
                      horizontal: horizontal,
                      fotografia: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ColoredBox(
                          color: fondoVisor,
                          child: Center(
                            child: InteractiveViewer(
                              minScale: 1,
                              maxScale: 5,
                              child: RotatedBox(
                                quarterTurns: widget.giros,
                                child: ImagenAutenticada(
                                  widget.url,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, hijo, progreso) =>
                                      progreso == null
                                      ? CustomPaint(
                                          painter: _FondoTransparencia(
                                            claro: tema
                                                .colorScheme
                                                .surfaceContainerLow,
                                            gris: tema
                                                .colorScheme
                                                .surfaceContainerHighest,
                                          ),
                                          child: hijo,
                                        )
                                      : const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                  errorBuilder: (context, error, _) =>
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Container(
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Arrastrá o pellizcá para acercar',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
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

  Widget _conDetalles({required Widget fotografia, required bool horizontal}) {
    final detalles = widget.detalles;
    if (detalles == null) return fotografia;
    final panel = _DetallesFotografia(imagen: detalles);
    if (horizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: fotografia),
          const SizedBox(width: 12),
          SizedBox(width: 230, child: SingleChildScrollView(child: panel)),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, limites) => Column(
        children: [
          Expanded(child: fotografia),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (limites.maxHeight * .5).clamp(0.0, 190.0),
            ),
            child: SingleChildScrollView(child: panel),
          ),
        ],
      ),
    );
  }
}

class _DetallesFotografia extends StatelessWidget {
  const _DetallesFotografia({required this.imagen});
  final Imagen imagen;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    Widget dato(String etiqueta, String valor) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: tema.textTheme.labelSmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurface,
          ),
        ),
      ],
    );
    final nombre = imagen.nombreOriginal?.trim();
    return Container(
      key: const ValueKey('detalles-fotografia'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagen.pendienteEdicion) ...[
              Text(
                'Pendiente de edición · Impresión bloqueada',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
            ],
            dato(
              'Nombre del archivo',
              nombre == null || nombre.isEmpty
                  ? 'Sin nombre registrado'
                  : nombre,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                dato(
                  'Fecha de creación',
                  Auditoria.formatear(imagen.creadaEn) ?? 'Sin registro',
                ),
                dato(
                  'Última edición',
                  Auditoria.formatear(imagen.actualizadaEn) ?? 'Sin registro',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// El damero permite ver los píxeles transparentes sin alterar el PNG.
class _FondoTransparencia extends CustomPainter {
  const _FondoTransparencia({required this.claro, required this.gris});
  final Color claro;
  final Color gris;

  @override
  void paint(Canvas canvas, Size size) {
    const lado = 16.0;
    final pinturaClara = Paint()..color = claro;
    final pinturaGris = Paint()..color = gris;
    canvas.drawRect(Offset.zero & size, pinturaClara);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var fila = 0; fila * lado < size.height; fila++) {
      for (var columna = 0; columna * lado < size.width; columna++) {
        if ((fila + columna).isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(columna * lado, fila * lado, lado, lado),
            pinturaGris,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FondoTransparencia oldDelegate) =>
      oldDelegate.claro != claro || oldDelegate.gris != gris;
}
