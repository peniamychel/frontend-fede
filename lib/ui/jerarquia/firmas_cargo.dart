import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/visor_imagen.dart';
import '../widgets/estados.dart';
import 'preparar_imagen_directorio.dart';

/// Firma manuscrita y vista del pie de firma construido automáticamente.
class FirmasCargo extends StatefulWidget {
  const FirmasCargo({super.key, required this.cargo, required this.alCambiar});

  final Cargo cargo;
  final VoidCallback alCambiar;

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
              'Firma',
              style: tema.textTheme.labelLarge?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, restricciones) {
            final firma = _ranuraFirma(context);
            final pie = _pieAutomatico(context);
            if (restricciones.maxWidth < 430) {
              return Column(children: [firma, const SizedBox(height: 12), pie]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 150, child: firma),
                const SizedBox(width: 12),
                Expanded(child: pie),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _ranuraFirma(BuildContext context) {
    final tema = Theme.of(context);
    final url = widget.cargo.firmaUrl;
    return Column(
      children: [
        Container(
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            border: Border.all(
              color: url == null
                  ? tema.colorScheme.outlineVariant
                  : tema.colorScheme.primary,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _ocupado
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : url == null
              ? InkWell(
                  onTap: _subirFirma,
                  child: const Center(
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Colors.black26,
                    ),
                  ),
                )
              : _vistaFirma(url),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              onPressed: _ocupado ? null : _subirFirma,
              child: Text(url == null ? 'Subir firma' : 'Cambiar'),
            ),
            if (url != null)
              IconButton(
                tooltip: 'Borrar firma',
                onPressed: _ocupado ? null : _borrarFirma,
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                icon: Icon(Icons.close, color: tema.colorScheme.error),
              ),
          ],
        ),
      ],
    );
  }

  Widget _pieAutomatico(BuildContext context) {
    final tema = Theme.of(context);
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
          Text('Pie de firma automático', style: tema.textTheme.labelMedium),
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
            'Se construye con el productor, el cargo y la organización.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vistaFirma(String url) {
    final absoluta = ApiConfig.urlAbsoluta(url);
    return InkWell(
      onTap: () => VisorImagen.mostrar(
        context,
        url: absoluta,
        titulo: 'Firma',
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

  Future<void> _subirFirma() async {
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
    final preparada = await prepararImagenDirectorio(
      context,
      archivo: elegido,
      clase: ClaseImagenDirectorio.firma,
    );
    if (preparada == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await PadronScope.of(context).directorios.subirImagen(
        cargoId: widget.cargo.id,
        tipo: TipoImagenCargo.firma,
        bytes: preparada.bytes,
        nombreArchivo: preparada.nombreArchivo,
      );
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarExito(
        context,
        'Firma guardada',
        detalle: 'Guardada como PNG con transparencia.',
      );
      widget.alCambiar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarError(context, e);
    }
  }

  Future<void> _borrarFirma() async {
    setState(() => _ocupado = true);
    try {
      await PadronScope.of(
        context,
      ).directorios.eliminarImagen(widget.cargo.id, TipoImagenCargo.firma);
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
