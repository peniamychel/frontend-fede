import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/fondo_ia.dart';
import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import '../widgets/zona_soltar_archivos.dart';
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
  final ImagePicker _selectorImagenes = ImagePicker();
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recuperarImagen());
  }

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

    return ZonaSoltarArchivos(
      habilitada: !_ocupado,
      extensionesPermitidas: extensionesImagen,
      alSoltar: (archivos) => _previsualizarYSubir(archivos.first),
      child: Row(
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
      ),
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
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
        ] else ...[
          Text('Fotografía cargada', style: tema.textTheme.titleSmall),
          const SizedBox(height: 6),
          _dato(context, 'Foto', '${foto.dimensiones} · ${foto.tamanoLegible}'),
          if (mini != null)
            _dato(
              context,
              'Miniatura',
              '${mini.dimensiones} · ${mini.tamanoLegible}',
            ),
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
                size: 18,
              ),
              label: Text(foto == null ? 'Subir foto' : 'Reemplazar'),
            ),
            if (foto != null)
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
    );
  }

  Widget _dato(BuildContext context, String etiqueta, String valor) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$etiqueta: ',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
            TextSpan(text: valor, style: tema.textTheme.bodySmall),
          ],
        ),
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
            Icon(
              Icons.person_outline,
              size: 40,
              color: tema.colorScheme.outline,
            ),
            const SizedBox(height: 6),
            Text(
              'Sin foto',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
            errorBuilder: (context, error, _) => Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
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
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              subtitle: const Text('Abrir la cámara del dispositivo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              subtitle: const Text('Seleccionar una imagen guardada'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;

    try {
      final archivo = await _selectorImagenes.pickImage(
        source: origen,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: false,
      );
      if (archivo == null || !mounted) return;
      await _previsualizarYSubir(archivo);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  /// Android puede cerrar la actividad mientras su aplicación de cámara está
  /// abierta. image_picker conserva el resultado para recuperarlo al volver.
  Future<void> _recuperarImagen() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final perdido = await _selectorImagenes.retrieveLostData();
      if (!mounted || perdido.isEmpty) return;
      if (perdido.exception != null) {
        mostrarError(context, perdido.exception!);
        return;
      }
      final archivo = perdido.file ?? perdido.files?.firstOrNull;
      if (archivo != null) await _previsualizarYSubir(archivo);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _previsualizarYSubir(XFile archivo) async {
    final bytes = await archivo.readAsBytes();
    if (!mounted || bytes.isEmpty) return;
    final elegido = PlatformFile(
      name: archivo.name.isEmpty
          ? 'foto-${DateTime.now().millisecondsSinceEpoch}.jpg'
          : archivo.name,
      size: bytes.length,
      bytes: bytes,
    );

    final decision = await showDialog<_Decision>(
      context: context,
      builder: (context) => _VistaPrevia(archivo: elegido),
    );
    if (decision == null || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final resultado = await PadronScope.of(context).productores.subirImagen(
        productorId: widget.productorId,
        bytes: decision.bytes,
        nombreArchivo: decision.nombreArchivo,
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
        content: const Text(
          'Se eliminan la foto y su miniatura. Podés subir '
          'otra cuando quieras.',
        ),
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
      await PadronScope.of(
        context,
      ).productores.eliminarImagen(widget.productorId);
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
  const _Decision({required this.bytes, required this.nombreArchivo});

  final Uint8List bytes;
  final String nombreArchivo;
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
  Uint8List? _fotoPreparada;
  bool _quitarFondo = true;
  bool _procesando = false;
  bool _ajustandoRecorte = false;
  String? _errorPreparacion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final bytes = Uint8List.fromList(widget.archivo.bytes!);

    return AlertDialog(
      title: const Text('Recortar y subir'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          physics: _ajustandoRecorte
              ? const NeverScrollableScrollPhysics()
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Acomodá cabeza y hombros dentro del cuadro. La foto se '
                'guardará cuadrada.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              RecortadorImagen(
                bytes: bytes,
                alCambiar: (recorte) {
                  if (!mounted) return;
                  setState(() {
                    _recorte = recorte;
                    _fotoPreparada = null;
                    _errorPreparacion = null;
                  });
                },
                proporcionFija: Proporcion.cuadrada,
                alCambiarInteraccion: (ajustando) {
                  if (!mounted || _ajustandoRecorte == ajustando) return;
                  setState(() => _ajustandoRecorte = ajustando);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _quitarFondo,
                onChanged: _procesando
                    ? null
                    : (valor) => setState(() {
                        _quitarFondo = valor;
                        _fotoPreparada = null;
                        _errorPreparacion = null;
                      }),
                title: const Text('Quitar fondo'),
                subtitle: Text(
                  _quitarFondo
                      ? 'Conserva automáticamente a la persona y guarda PNG transparente.'
                      : 'Guarda el recorte cuadrado sin eliminar el fondo.',
                  style: tema.textTheme.bodySmall,
                ),
              ),
              if (_fotoPreparada != null) ...[
                const SizedBox(height: 8),
                Text('Vista previa', style: tema.textTheme.labelLarge),
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: tema.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(_fotoPreparada!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PNG cuadrado · ${pesoLegible(_fotoPreparada!.length)}',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.outline,
                  ),
                ),
              ],
              if (_errorPreparacion != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorPreparacion!,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.error,
                  ),
                ),
              ],
              Text(
                widget.archivo.name,
                style: tema.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                pesoLegible(widget.archivo.size),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tema.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: tema.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Primero se prepara una vista previa. La foto se procesa '
                        'localmente en este equipo; no se envía a un servicio externo.',
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
        OutlinedButton.icon(
          onPressed: _procesando ? null : _preparar,
          icon: _procesando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high_outlined, size: 18),
          label: Text(_procesando ? 'Procesando…' : 'Preparar vista previa'),
        ),
        FilledButton(
          onPressed: _fotoPreparada == null || _procesando
              ? null
              : () => Navigator.of(context).pop(
                  _Decision(
                    bytes: _fotoPreparada!,
                    nombreArchivo: _nombrePng(),
                  ),
                ),
          child: const Text('Subir'),
        ),
      ],
    );
  }

  Future<void> _preparar() async {
    final recorte = _recorte;
    if (recorte == null) {
      setState(() => _errorPreparacion = 'Esperá a que cargue la fotografía.');
      return;
    }
    if (!fondoIaDisponible) {
      setState(
        () => _errorPreparacion =
            'La eliminación de fondo está disponible por ahora en la versión web.',
      );
      return;
    }

    setState(() {
      _procesando = true;
      _errorPreparacion = null;
      _fotoPreparada = null;
    });
    try {
      final resultado = await prepararFotoSinFondo(
        bytes: Uint8List.fromList(widget.archivo.bytes!),
        recorte: recorte,
        quitarFondo: _quitarFondo,
        tipoMime: _tipoMime(),
      );
      if (!mounted) return;
      setState(() => _fotoPreparada = resultado.bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorPreparacion = '$e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  String _nombrePng() {
    final nombre = widget.archivo.name;
    final punto = nombre.lastIndexOf('.');
    return '${punto <= 0 ? nombre : nombre.substring(0, punto)}.png';
  }

  String _tipoMime() {
    final nombre = widget.archivo.name.toLowerCase();
    if (nombre.endsWith('.png')) return 'image/png';
    if (nombre.endsWith('.webp')) return 'image/webp';
    if (nombre.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
