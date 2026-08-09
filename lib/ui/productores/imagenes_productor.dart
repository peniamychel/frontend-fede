import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import 'recortador_imagen.dart';
import 'visor_imagen.dart';

/// Fotografía del productor.
///
/// Se sube **una sola** imagen, del tamaño que salga de la cámara. El servidor
/// deriva la foto de consulta y la miniatura de los listados, y las comprime.
/// Acá no se valida el peso: hacerlo sería devolverle al usuario un problema
/// que el servidor ya resuelve.
class ImagenesProductor extends StatefulWidget {
  const ImagenesProductor({
    super.key,
    required this.productorId,
    required this.imagenes,
    required this.alCambiar,
  });

  final int productorId;

  /// Las variantes que hay guardadas. Vienen del backend, no se eligen.
  final List<Imagen> imagenes;

  final VoidCallback alCambiar;

  @override
  State<ImagenesProductor> createState() => _ImagenesProductorState();
}

class _ImagenesProductorState extends State<ImagenesProductor> {
  bool _ocupado = false;

  Imagen? get _original => _buscar(TipoImagen.original);
  Imagen? get _miniatura => _buscar(TipoImagen.miniatura);

  Imagen? _buscar(TipoImagen tipo) {
    for (final i in widget.imagenes) {
      if (i.tipo == tipo) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final foto = _original;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: tema.colorScheme.surfaceContainerHighest,
                border: Border.all(color: tema.colorScheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: _ocupado
                  ? const Center(child: CircularProgressIndicator())
                  : foto == null
                      ? _vacia(context)
                      : _vista(context, foto),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _detalle(context, foto)),
      ],
    );
  }

  Widget _detalle(BuildContext context, Imagen? foto) {
    final tema = Theme.of(context);
    final mini = _miniatura;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (foto == null) ...[
          Text('Sin fotografía', style: tema.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Subí una imagen del tamaño que sea. El servidor la reduce y '
            'genera la miniatura para los listados.',
            style: tema.textTheme.bodySmall
                ?.copyWith(color: tema.colorScheme.outline),
          ),
        ] else ...[
          Text('Fotografía cargada', style: tema.textTheme.titleSmall),
          const SizedBox(height: 6),
          _dato(context, 'Foto', '${foto.dimensiones} · ${foto.tamanoLegible}'),
          if (mini != null)
            _dato(context, 'Miniatura',
                '${mini.dimensiones} · ${mini.tamanoLegible}'),
          if (foto.nombreOriginal != null)
            _dato(context, 'Archivo', foto.nombreOriginal!),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _ocupado ? null : _elegirYSubir,
              icon: Icon(
                  foto == null ? Icons.add_a_photo_outlined : Icons.swap_horiz,
                  size: 18),
              label: Text(foto == null ? 'Subir foto' : 'Reemplazar'),
            ),
            if (foto != null)
              TextButton.icon(
                onPressed: _ocupado ? null : _borrar,
                icon: Icon(Icons.delete_outline,
                    size: 18, color: tema.colorScheme.error),
                label: Text('Borrar',
                    style: TextStyle(color: tema.colorScheme.error)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dato(BuildContext context, String etiqueta, String valor) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$etiqueta: ',
            style: tema.textTheme.bodySmall
                ?.copyWith(color: tema.colorScheme.outline),
          ),
          TextSpan(text: valor, style: tema.textTheme.bodySmall),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _vacia(BuildContext context) {
    final tema = Theme.of(context);
    return InkWell(
      onTap: _elegirYSubir,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 40, color: tema.colorScheme.outline),
            const SizedBox(height: 6),
            Text('Sin foto',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.outline)),
          ],
        ),
      ),
    );
  }

  Widget _vista(BuildContext context, Imagen foto) {
    // La URL la da el backend: el archivo vive en su almacén, no en la base.
    final url = ApiConfig.urlAbsoluta(foto.url);

    return InkWell(
      onTap: () => VisorImagen.mostrar(
        context,
        url: url,
        titulo: 'Fotografía',
        subtitulo: '${foto.dimensiones} · ${foto.tamanoLegible}',
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, hijo, progreso) => progreso == null
                ? hijo
                : const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
            errorBuilder: (context, error, _) => Center(
              child: Icon(Icons.broken_image_outlined,
                  color: Theme.of(context).colorScheme.error),
            ),
          ),
          const Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.zoom_out_map, size: 18, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Acciones ----------

  Future<void> _elegirYSubir() async {
    final PlatformFile elegido;
    try {
      final resultado = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final archivo = resultado?.files.firstOrNull;
      if (archivo == null || archivo.bytes == null) return;
      elegido = archivo;
    } catch (e) {
      if (mounted) mostrarError(context, e);
      return;
    }

    if (!mounted) return;

    final decision = await showDialog<_Decision>(
      context: context,
      builder: (context) => _VistaPrevia(archivo: elegido),
    );
    if (decision == null || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final resultado =
          await PadronScope.of(context).productores.subirImagen(
                productorId: widget.productorId,
                bytes: elegido.bytes!,
                nombreArchivo: elegido.name,
                recorte: decision.recorte,
              );
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarExito(
        context,
        'Foto guardada',
        detalle: resultado.huboReduccion
            ? 'De ${pesoLegible(resultado.tamanoSubidoBytes)} a '
                '${pesoLegible(resultado.original.tamanoBytes)}, '
                '${resultado.porcentajeReduccion} % menos. '
                'Miniatura de ${pesoLegible(resultado.miniatura.tamanoBytes)}.'
            : null,
      );
      widget.alCambiar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarError(context, e);
    }
  }

  Future<void> _borrar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar la fotografía?'),
        content: const Text('Se eliminan la foto y su miniatura. Podés subir '
            'otra cuando quieras.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await PadronScope.of(context)
          .productores
          .eliminarImagen(widget.productorId);
      if (!mounted) return;
      setState(() => _ocupado = false);
      widget.alCambiar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarError(context, e);
    }
  }
}

/// Lo que devuelve el diálogo: null si se canceló, o el recorte elegido —que a
/// su vez puede ser null cuando se quiere la imagen entera.
class _Decision {
  const _Decision(this.recorte);

  final Recorte? recorte;
}

/// Vista previa con recorte, antes de mandar la foto.
///
/// No bloquea por peso: el archivo puede pesar lo que sea y el servidor lo
/// reduce. Lo que sí permite es elegir qué parte conservar, porque muchas fotos
/// de padrón traen mucho fondo y lo que importa es la cara.
class _VistaPrevia extends StatefulWidget {
  const _VistaPrevia({required this.archivo});

  final PlatformFile archivo;

  @override
  State<_VistaPrevia> createState() => _VistaPreviaState();
}

class _VistaPreviaState extends State<_VistaPrevia> {
  Recorte? _recorte;
  int? _anchoImagen;
  int? _altoImagen;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final bytes = Uint8List.fromList(widget.archivo.bytes!);

    return AlertDialog(
      title: const Text('Recortar y subir'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Arrastrá el marco para elegir qué parte se guarda.',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.outline),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              RecortadorImagen(
                bytes: bytes,
                alCargarImagen: (ancho, alto) {
                  if (!mounted) return;
                  setState(() {
                    _anchoImagen = ancho;
                    _altoImagen = alto;
                  });
                },
                alCambiar: (recorte) {
                  if (!mounted) return;
                  setState(() => _recorte = recorte);
                },
              ),
              const SizedBox(height: 12),
              Text(widget.archivo.name,
                  style: tema.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
              Text(pesoLegible(widget.archivo.size),
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.outline),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tema.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 18, color: tema.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'El recorte se aplica sobre la foto original, en su '
                        'resolución completa. Después se reduce y se genera la '
                        'miniatura.',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_Decision(_recorteAEnviar())),
          child: const Text('Subir'),
        ),
      ],
    );
  }

  /// Omite el recorte cuando abarca la imagen entera: mandarlo daría el mismo
  /// resultado y solo agregaría trabajo al servidor.
  Recorte? _recorteAEnviar() {
    final recorte = _recorte;
    if (recorte == null) return null;
    final ancho = _anchoImagen;
    final alto = _altoImagen;
    if (ancho != null && alto != null && recorte.esCompleto(ancho, alto)) {
      return null;
    }
    return recorte;
  }
}
