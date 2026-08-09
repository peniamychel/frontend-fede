import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/visor_imagen.dart';
import '../widgets/estados.dart';

/// Firma y pie de firma de un período del directorio.
///
/// Se suben en cualquier tamaño; el servidor las reduce a 200 píxeles de lado
/// mayor conservando la proporción, de modo que una firma apaisada no termine
/// estirada en un cuadrado.
class FirmasCargo extends StatefulWidget {
  const FirmasCargo({
    super.key,
    required this.cargo,
    required this.alCambiar,
  });

  final Cargo cargo;

  /// Se llama tras subir o borrar, para que la pantalla se recargue.
  final VoidCallback alCambiar;

  @override
  State<FirmasCargo> createState() => _FirmasCargoState();
}

class _FirmasCargoState extends State<FirmasCargo> {
  TipoImagenCargo? _ocupadoEn;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.draw_outlined, size: 16, color: tema.colorScheme.outline),
            const SizedBox(width: 6),
            Text('Firmas',
                style: tema.textTheme.labelLarge
                    ?.copyWith(color: tema.colorScheme.outline)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final tipo in TipoImagenCargo.values) ...[
              Expanded(child: _ranura(context, tipo)),
              if (tipo != TipoImagenCargo.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _ranura(BuildContext context, TipoImagenCargo tipo) {
    final tema = Theme.of(context);
    final url = widget.cargo.urlDe(tipo);
    final ocupado = _ocupadoEn == tipo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: tipo.detalle,
          child: Container(
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              // Fondo claro siempre: una firma es trazo oscuro sobre papel, y
              // en tema oscuro sobre fondo oscuro no se vería.
              color: Colors.white,
              border: Border.all(
                color: url == null
                    ? tema.colorScheme.outlineVariant
                    : tema.colorScheme.primary,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ocupado
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : url == null
                    ? _vacia(context, tipo)
                    : _vista(context, tipo, url),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: TextButton(
                onPressed: ocupado ? null : () => _subir(tipo),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  url == null ? tipo.etiqueta : 'Cambiar',
                  style: tema.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (url != null)
              IconButton(
                tooltip: 'Borrar ${tipo.etiqueta.toLowerCase()}',
                onPressed: ocupado ? null : () => _borrar(tipo),
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                icon: Icon(Icons.close, color: tema.colorScheme.error),
              ),
          ],
        ),
      ],
    );
  }

  Widget _vacia(BuildContext context, TipoImagenCargo tipo) {
    return InkWell(
      onTap: () => _subir(tipo),
      child: Center(
        child: Icon(Icons.add_photo_alternate_outlined,
            size: 22, color: Colors.black26),
      ),
    );
  }

  Widget _vista(BuildContext context, TipoImagenCargo tipo, String url) {
    final absoluta = ApiConfig.urlAbsoluta(url);
    return InkWell(
      onTap: () => VisorImagen.mostrar(
        context,
        url: absoluta,
        titulo: tipo.etiqueta,
        subtitulo: widget.cargo.productorNombre,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Image.network(
          absoluta,
          fit: BoxFit.contain,
          errorBuilder: (context, error, _) => const Center(
            child: Icon(Icons.broken_image_outlined,
                size: 20, color: Colors.black26),
          ),
        ),
      ),
    );
  }

  // ---------- Acciones ----------

  Future<void> _subir(TipoImagenCargo tipo) async {
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
    setState(() => _ocupadoEn = tipo);

    try {
      await PadronScope.of(context).directorios.subirImagen(
            cargoId: widget.cargo.id,
            tipo: tipo,
            bytes: elegido.bytes!,
            nombreArchivo: elegido.name,
          );
      if (!mounted) return;
      setState(() => _ocupadoEn = null);
      mostrarExito(context, '${tipo.etiqueta} guardada',
          detalle: 'Reducida a 200 px de lado mayor.');
      widget.alCambiar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupadoEn = null);
      mostrarError(context, e);
    }
  }

  Future<void> _borrar(TipoImagenCargo tipo) async {
    setState(() => _ocupadoEn = tipo);
    try {
      await PadronScope.of(context)
          .directorios
          .eliminarImagen(widget.cargo.id, tipo);
      if (!mounted) return;
      setState(() => _ocupadoEn = null);
      widget.alCambiar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupadoEn = null);
      mostrarError(context, e);
    }
  }
}
