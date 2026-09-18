import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/fondo_ia.dart';
import '../../core/guardar_archivo.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (foto == null) ...[
          Text('Sin fotografía', style: tema.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Subí una imagen del tamaño que sea. El servidor prepara la fotografía.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
        ] else ...[
          Text('Fotografía cargada', style: tema.textTheme.titleSmall),
          const SizedBox(height: 6),
          _dato(context, 'Foto', '${foto.dimensiones} · ${foto.tamanoLegible}'),
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
        alDescargar: () => _descargar(),
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

  Future<void> _descargar() async {
    try {
      final archivo = await PadronScope.of(
        context,
      ).productores.descargarFotografia(widget.productorId);
      await guardarArchivo(
        archivo.bytes,
        archivo.nombreArchivo,
        archivo.tipoMime,
      );
      if (mounted) mostrarExito(context, 'Fotografía descargada.');
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

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

    final decision = await Navigator.of(context, rootNavigator: true)
        .push<_Decision>(
          MaterialPageRoute<_Decision>(
            builder: (context) => _VistaPrevia(archivo: elegido),
          ),
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
                  '${resultado.porcentajeReduccion} % menos.'
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

/// Fotografía preparada por el editor. Al cancelar, la ruta devuelve null.
class _Decision {
  const _Decision({required this.bytes, required this.nombreArchivo});

  final Uint8List bytes;
  final String nombreArchivo;
}

/// Editor a pantalla completa para preparar la fotografía antes de subirla.
class _VistaPrevia extends StatefulWidget {
  const _VistaPrevia({required this.archivo});

  final PlatformFile archivo;

  @override
  State<_VistaPrevia> createState() => _VistaPreviaState();
}

class _VistaPreviaState extends State<_VistaPrevia> {
  Recorte? _recorte;
  bool _quitarFondo = true;
  bool _procesando = false;
  bool _ajustandoRecorte = false;
  String? _errorPreparacion;

  bool get _esPng => widget.archivo.name.toLowerCase().endsWith('.png');
  bool get _soloRecortar => _esPng && !_quitarFondo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final bytes = Uint8List.fromList(widget.archivo.bytes!);

    return Scaffold(
      appBar: AppBar(title: const Text('Recortar y subir')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
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
                  AbsorbPointer(
                    absorbing: _procesando,
                    child: RecortadorImagen(
                      bytes: bytes,
                      alCambiar: (recorte) {
                        if (!mounted) return;
                        setState(() {
                          _recorte = recorte;
                          _errorPreparacion = null;
                        });
                      },
                      proporcionFija: Proporcion.cuadrada,
                      alCambiarInteraccion: (ajustando) {
                        if (!mounted || _ajustandoRecorte == ajustando) return;
                        setState(() => _ajustandoRecorte = ajustando);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_esPng)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _quitarFondo,
                      onChanged: _procesando
                          ? null
                          : (valor) => setState(() {
                              _quitarFondo = valor;
                              _errorPreparacion = null;
                            }),
                      title: const Text('Quitar fondo'),
                      subtitle: Text(
                        _quitarFondo
                            ? 'Conserva automáticamente a la persona y guarda PNG transparente.'
                            : 'Guardar recortando la imagen: este PNG ya está sin fondo.',
                        style: tema.textTheme.bodySmall,
                      ),
                    ),
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
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              if (!_soloRecortar)
                OutlinedButton.icon(
                  onPressed: _procesando ? null : _preparar,
                  icon: _procesando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high_outlined, size: 18),
                  label: Text(_procesando ? 'Procesando…' : 'Procesar imagen'),
                ),
              if (_soloRecortar)
                FilledButton(
                  onPressed:
                      _procesando || _ajustandoRecorte || _recorte == null
                      ? null
                      : _preparar,
                  child: Text(
                    _soloRecortar && _procesando ? 'Procesando…' : 'Subir',
                  ),
                ),
            ],
          ),
        ),
      ),
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
    });
    try {
      final resultado = await prepararFotoSinFondo(
        bytes: Uint8List.fromList(widget.archivo.bytes!),
        recorte: recorte,
        quitarFondo: !_soloRecortar,
        tipoMime: _tipoMime(),
      );
      if (!mounted) return;
      if (!_soloRecortar) {
        final aceptada = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Vista previa'),
            scrollable: true,
            content: SizedBox(
              width: 420,
              height: (MediaQuery.sizeOf(context).height * .5).clamp(1, 420),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Image.memory(resultado.bytes, fit: BoxFit.contain),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Atrás'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Subir'),
              ),
            ],
          ),
        );
        if (!mounted || aceptada != true) return;
      }
      Navigator.of(
        context,
      ).pop(_Decision(bytes: resultado.bytes, nombreArchivo: _nombrePng()));
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
