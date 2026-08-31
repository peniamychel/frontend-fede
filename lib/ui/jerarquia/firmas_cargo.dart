import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/visor_imagen.dart';
import '../widgets/estados.dart';
import '../widgets/zona_soltar_archivos.dart';
import 'elegir_imagen_directorio.dart';
import 'preparar_imagen_directorio.dart';

/// Firma manuscrita, pie de firma en imagen y respaldo textual de un cargo.
class FirmasCargo extends StatefulWidget {
  const FirmasCargo({
    super.key,
    required this.cargo,
    required this.alCambiar,
    required this.permitePieFirmaImagen,
    required this.firmaObligatoria,
  });

  final Cargo cargo;
  final VoidCallback alCambiar;
  final bool permitePieFirmaImagen;
  final bool firmaObligatoria;

  @override
  State<FirmasCargo> createState() => _FirmasCargoState();
}

class _FirmasCargoState extends State<FirmasCargo> {
  bool _ocupado = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.draw_outlined,
              size: 16,
              color: tema.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              'Firma y pie de firma',
              style: tema.textTheme.labelLarge?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, restricciones) {
            final firma = _ranuraImagen(
              context,
              titulo: 'Firma manuscrita',
              tipo: TipoImagenCargo.firma,
              clase: ClaseImagenDirectorio.firma,
              url: widget.cargo.firmaUrl,
              habilitada: true,
              obligatoria: widget.firmaObligatoria,
            );
            final pie = _ranuraImagen(
              context,
              titulo: 'Pie de firma en imagen',
              tipo: TipoImagenCargo.pieFirma,
              clase: ClaseImagenDirectorio.pieFirma,
              url: widget.cargo.pieFirmaUrl,
              habilitada: widget.permitePieFirmaImagen,
              obligatoria: false,
            );
            if (restricciones.maxWidth < 520) {
              return Column(children: [firma, const SizedBox(height: 12), pie]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: firma),
                const SizedBox(width: 12),
                Expanded(child: pie),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _pieAutomatico(context),
      ],
    );
  }

  Widget _ranuraImagen(
    BuildContext context, {
    required String titulo,
    required TipoImagenCargo tipo,
    required ClaseImagenDirectorio clase,
    required String? url,
    required bool habilitada,
    required bool obligatoria,
  }) {
    final tema = Theme.of(context);
    final etiquetaEstado = obligatoria
        ? 'Obligatoria'
        : habilitada
        ? 'Opcional'
        : 'Deshabilitada';
    return ZonaSoltarArchivos(
      habilitada: habilitada && !_ocupado,
      extensionesPermitidas: extensionesImagen,
      alSoltar: (archivos) async {
        final elegido = await archivoSoltadoAPlatformFile(archivos.first);
        if (!mounted) return;
        await _prepararYSubir(tipo, clase, elegido);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(titulo, style: tema.textTheme.labelMedium)),
              Text(
                etiquetaEstado,
                style: tema.textTheme.labelSmall?.copyWith(
                  color: obligatoria
                      ? tema.colorScheme.error
                      : tema.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: habilitada || url != null
                  ? Colors.white
                  : tema.colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: url == null
                    ? tema.colorScheme.outlineVariant
                    : tema.colorScheme.primary,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _ocupado
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : url != null
                ? _vistaImagen(url, titulo)
                : habilitada
                ? InkWell(
                    onTap: () => _subir(tipo, clase),
                    child: const Center(
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: Colors.black26,
                      ),
                    ),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 20,
                            color: tema.colorScheme.outline,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No disponible para sindicatos',
                            textAlign: TextAlign.center,
                            style: tema.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: _ocupado || !habilitada
                    ? null
                    : () => _subir(tipo, clase),
                child: Text(
                  url == null ? 'Subir ${clase.etiqueta}' : 'Cambiar',
                ),
              ),
              if (url != null)
                TextButton.icon(
                  onPressed: _ocupado ? null : () => _editar(tipo, clase),
                  icon: const Icon(Icons.tune, size: 17),
                  label: const Text('Editar'),
                ),
              if (url != null)
                IconButton(
                  tooltip: 'Borrar ${clase.etiqueta}',
                  onPressed: _ocupado ? null : () => _borrar(tipo),
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  icon: Icon(Icons.close, color: tema.colorScheme.error),
                ),
            ],
          ),
          if (habilitada) const AyudaArrastrarArchivo(),
          if (!habilitada)
            Text(
              'Puede habilitarse más adelante desde la configuración del backend.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }

  Widget _pieAutomatico(BuildContext context) {
    final tema = Theme.of(context);
    if (widget.cargo.pieFirmaUrl != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: tema.colorScheme.primaryContainer,
          border: Border.all(color: tema.colorScheme.primary),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: tema.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'La credencial usará la imagen de pie de firma cargada; '
                'el texto automático no se imprimirá.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: tema.colorScheme.surfaceContainerHighest.withValues(alpha: .45),
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pie de firma automático de respaldo',
            style: tema.textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              widget.cargo.pieFirma ?? '',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Se usa mientras no haya una imagen de pie de firma.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaImagen(String url, String titulo) {
    final absoluta = ApiConfig.urlAbsoluta(url);
    return InkWell(
      onTap: () => VisorImagen.mostrar(
        context,
        url: absoluta,
        titulo: titulo,
        subtitulo: widget.cargo.productorNombre,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Image.network(
          absoluta,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.black26),
          ),
        ),
      ),
    );
  }

  Future<void> _subir(TipoImagenCargo tipo, ClaseImagenDirectorio clase) async {
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
    await _prepararYSubir(tipo, clase, elegido);
  }

  Future<void> _prepararYSubir(
    TipoImagenCargo tipo,
    ClaseImagenDirectorio clase,
    PlatformFile elegido,
  ) async {
    final preparada = await prepararImagenDirectorio(
      context,
      archivo: elegido,
      clase: clase,
    );
    if (preparada == null || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await PadronScope.of(context).directorios.subirImagen(
        cargoId: widget.cargo.id,
        tipo: tipo,
        bytes: preparada.bytes,
        nombreArchivo: preparada.nombreArchivo,
        originalBytes: preparada.originalBytes,
        nombreOriginal: preparada.nombreOriginal,
      );
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarExito(
        context,
        '${tipo.etiqueta} guardado',
        detalle: 'Guardado como PNG con transparencia.',
      );
      widget.alCambiar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarError(context, e);
    }
  }

  Future<void> _editar(
    TipoImagenCargo tipo,
    ClaseImagenDirectorio clase,
  ) async {
    setState(() => _ocupado = true);
    try {
      final descarga = await PadronScope.of(
        context,
      ).directorios.descargarOriginalImagen(widget.cargo.id, tipo);
      if (!mounted) return;
      setState(() => _ocupado = false);
      final archivo = PlatformFile(
        name: descarga.nombreArchivo,
        size: descarga.bytes.length,
        bytes: Uint8List.fromList(descarga.bytes),
      );
      await _prepararYSubir(tipo, clase, archivo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarError(context, e);
    }
  }

  Future<void> _borrar(TipoImagenCargo tipo) async {
    setState(() => _ocupado = true);
    try {
      await PadronScope.of(
        context,
      ).directorios.eliminarImagen(widget.cargo.id, tipo);
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
