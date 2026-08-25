import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/visor_imagen.dart';
import '../widgets/estados.dart';
import '../widgets/zona_soltar_archivos.dart';
import 'elegir_imagen_directorio.dart';
import 'preparar_imagen_directorio.dart';

/// Sello institucional único del sindicato, central o federación.
class SelloDirectorio extends StatefulWidget {
  const SelloDirectorio({
    super.key,
    required this.directorio,
    required this.alCambiar,
  });

  final Directorio directorio;
  final VoidCallback alCambiar;

  @override
  State<SelloDirectorio> createState() => _SelloDirectorioState();
}

class _SelloDirectorioState extends State<SelloDirectorio> {
  bool _ocupado = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final url = widget.directorio.selloUrl;
    return ZonaSoltarArchivos(
      habilitada: !_ocupado,
      extensionesPermitidas: extensionesImagen,
      alSoltar: (archivos) async {
        final elegido = await archivoSoltadoAPlatformFile(archivos.first);
        if (!mounted) return;
        await _prepararYSubir(elegido);
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 150,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tema.colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: _ocupado
                    ? const Center(
                        child: SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : url == null
                    ? InkWell(
                        onTap: _subir,
                        child: const Center(
                          child: Icon(
                            Icons.approval_outlined,
                            size: 34,
                            color: Colors.black26,
                          ),
                        ),
                      )
                    : _imagen(url),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.approval_outlined,
                          size: 20,
                          color: tema.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sello de ${widget.directorio.ambito.etiqueta.toLowerCase()}',
                            style: tema.textTheme.titleMedium,
                          ),
                        ),
                        if (widget.directorio.selloObligatorio)
                          Text(
                            'Obligatorio',
                            style: tema.textTheme.labelSmall?.copyWith(
                              color: tema.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pertenece a ${widget.directorio.ambitoNombre}. Se mantiene aunque cambien '
                      'las personas del directorio.',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _ocupado ? null : _subir,
                          icon: const Icon(Icons.upload_outlined, size: 18),
                          label: Text(
                            url == null ? 'Subir sello' : 'Cambiar sello',
                          ),
                        ),
                        if (url != null)
                          TextButton.icon(
                            onPressed: _ocupado ? null : _borrar,
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: tema.colorScheme.error,
                            ),
                            label: Text(
                              'Borrar',
                              style: TextStyle(color: tema.colorScheme.error),
                            ),
                          ),
                      ],
                    ),
                    const AyudaArrastrarArchivo(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagen(String url) {
    final absoluta = ApiConfig.urlAbsoluta(url);
    return InkWell(
      onTap: () => VisorImagen.mostrar(
        context,
        url: absoluta,
        titulo: 'Sello de ${widget.directorio.ambitoNombre}',
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Image.network(
          absoluta,
          fit: BoxFit.contain,
          errorBuilder: (context, error, _) => const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.black26),
          ),
        ),
      ),
    );
  }

  Future<void> _subir() async {
    late final PlatformFile elegido;
    try {
      final archivo = await elegirImagenDirectorio(context);
      if (archivo == null) return;
      elegido = archivo;
    } catch (e) {
      if (mounted) mostrarError(context, e);
      return;
    }

    if (!mounted) return;
    await _prepararYSubir(elegido);
  }

  Future<void> _prepararYSubir(PlatformFile elegido) async {
    final preparada = await prepararImagenDirectorio(
      context,
      archivo: elegido,
      clase: ClaseImagenDirectorio.sello,
    );
    if (preparada == null || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await PadronScope.of(context).directorios.subirSello(
        ambito: widget.directorio.ambito,
        id: widget.directorio.ambitoId,
        bytes: preparada.bytes,
        nombreArchivo: preparada.nombreArchivo,
      );
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarExito(
        context,
        'Sello guardado',
        detalle: 'Guardado como PNG con transparencia.',
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
        title: const Text('¿Borrar el sello?'),
        content: Text(
          'Se quitará el sello de ${widget.directorio.ambitoNombre}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await PadronScope.of(context).directorios.eliminarSello(
        widget.directorio.ambito,
        widget.directorio.ambitoId,
      );
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
