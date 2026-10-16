import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../core/fondo_ia.dart';
import '../../core/guardar_archivo.dart';
import '../../core/operacion_fotografia.dart';
import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import '../widgets/camara_windows_pagina.dart';
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
    this.editable = true,
    this.nombreProductor,
    this.ci,
  });

  final int productorId;

  /// Las variantes que hay guardadas. Vienen del backend, no se eligen.
  final List<Imagen> imagenes;

  final VoidCallback alCambiar;
  final bool editable;
  final String? nombreProductor;
  final String? ci;

  @override
  State<ImagenesProductor> createState() => _ImagenesProductorState();
}

class _ImagenesProductorState extends State<ImagenesProductor> {
  final ImagePicker _selectorImagenes = ImagePicker();
  bool _ocupado = false;
  OperacionFotografia? _operacion;
  static OperacionFotografia? _operacionEnCurso;
  static bool _recuperandoCamara = false;

  @override
  void didUpdateWidget(covariant ImagenesProductor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productorId != widget.productorId || !widget.editable) {
      _operacion?.cancelar();
      _operacion = null;
      _ocupado = false;
    }
  }

  @override
  void dispose() {
    _operacion?.cancelar();
    super.dispose();
  }

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
      habilitada: widget.editable && !_ocupado,
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
          if (foto.actualizadaEn != null)
            _dato(context, 'Última subida', _fecha(foto.actualizadaEn!)),
        ],
        const SizedBox(height: 12),
        if (widget.editable)
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
                  onPressed: _ocupado ? null : _editar,
                  icon: const Icon(Icons.crop, size: 18),
                  label: const Text('Editar'),
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
        if (widget.editable) const AyudaArrastrarArchivo(),
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
      onTap: widget.editable && !_ocupado ? _elegirYSubir : null,
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
    final productorId = widget.productorId;

    return InkWell(
      onTap: () => VisorImagen.mostrar(
        context,
        url: url,
        titulo: 'Fotografía',
        subtitulo: '${foto.dimensiones} · ${foto.tamanoLegible}',
        alDescargar: () => _descargar(),
        alEditar: widget.editable && !_ocupado
            ? () async {
                if (mounted && widget.productorId == productorId) {
                  await _editar();
                }
              }
            : null,
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

  String _fecha(DateTime fecha) {
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Future<void> _editar() async {
    if (!mounted || _ocupado || !widget.editable) return;
    final repositorio = PadronScope.of(context).productores;
    await _realizarOperacion((operacion) async {
      final archivo = await repositorio.descargarFotografia(
        operacion.productorId,
      );
      return XFile.fromData(
        Uint8List.fromList(archivo.bytes),
        name: 'fotografia.png',
        mimeType: 'image/png',
      );
    }, editar: true);
  }

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
    await _realizarOperacion(_seleccionarImagen);
  }

  Future<XFile?> _seleccionarImagen(OperacionFotografia operacion) async {
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
    if (origen == null || !_esLaOperacionActual(operacion)) return null;
    final esAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    try {
      if (esAndroid) {
        final pendiente = await FotoCamaraPendiente.leer();
        if (pendiente != null && pendiente.id != operacion.id) {
          throw StateError(
            'Hay una fotografía pendiente de ${pendiente.nombre}. Abrí su ficha para recuperarla antes de tomar otra.',
          );
        }
        await FotoCamaraPendiente.guardar(operacion);
      }
      if (!mounted || !_esLaOperacionActual(operacion)) return null;
      final esCamaraWindows =
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.windows &&
          origen == ImageSource.camera;
      return esCamaraWindows
          ? await abrirCamaraWindows(context)
          : await _selectorImagenes.pickImage(
              source: origen,
              preferredCameraDevice: CameraDevice.rear,
              requestFullMetadata: false,
            );
    } finally {
      if (esAndroid) {
        await FotoCamaraPendiente.borrarSiCorresponde(operacion.id);
      }
    }
  }

  /// Android puede cerrar la actividad mientras su aplicación de cámara está
  /// abierta. image_picker conserva el resultado para recuperarlo al volver.
  Future<void> _recuperarImagen() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _recuperandoCamara) {
      return;
    }
    _recuperandoCamara = true;
    try {
      final pendiente = await FotoCamaraPendiente.leer();
      if (!mounted || pendiente == null || _ocupado) return;
      if (pendiente.productorId != widget.productorId) {
        mostrarAviso(
          context,
          'Fotografía pendiente de ${pendiente.nombre}',
          detalle:
              'Abrí la ficha de ese productor para recuperar su fotografía.',
        );
        return;
      }
      await _realizarOperacion((operacion) async {
        try {
          final perdido = await _selectorImagenes.retrieveLostData();
          if (perdido.exception != null) throw perdido.exception!;
          return perdido.isEmpty
              ? null
              : perdido.file ?? perdido.files?.firstOrNull;
        } finally {
          await FotoCamaraPendiente.borrarSiCorresponde(operacion.id);
        }
      }, recuperada: pendiente);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      _recuperandoCamara = false;
    }
  }

  Future<void> _previsualizarYSubir(
    XFile archivo, {
    bool editar = false,
  }) async {
    await _realizarOperacion((_) async => archivo, editar: editar);
  }

  bool _esLaOperacionActual(OperacionFotografia operacion) =>
      mounted &&
      widget.editable &&
      widget.productorId == operacion.productorId &&
      identical(_operacion, operacion) &&
      operacion.vigente;

  Future<void> _realizarOperacion(
    Future<XFile?> Function(OperacionFotografia) seleccionar, {
    bool editar = false,
    OperacionFotografia? recuperada,
  }) async {
    // Se bloquea antes del primer await, también frente a dos eventos del mismo frame.
    if (!mounted || _ocupado || !widget.editable) return;
    if (!Visibility.of(context) ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        (_operacionEnCurso?.vigente ?? false)) {
      return;
    }
    final operacion =
        recuperada ??
        OperacionFotografia(
          productorId: widget.productorId,
          nombre: widget.nombreProductor ?? 'Productor ${widget.productorId}',
          ci: widget.ci,
        );
    if (operacion.productorId != widget.productorId) return;
    _operacionEnCurso = operacion;
    setState(() {
      _ocupado = true;
      _operacion = operacion;
    });
    try {
      final archivo = await seleccionar(operacion);
      if (!mounted || archivo == null || !_esLaOperacionActual(operacion)) {
        return;
      }
      final repositorio = PadronScope.of(context).productores;
      await _abrirEditor(archivo, operacion, repositorio, editar: editar);
    } catch (e) {
      if (mounted && _esLaOperacionActual(operacion)) mostrarError(context, e);
    } finally {
      operacion.cancelar();
      if (identical(_operacionEnCurso, operacion)) _operacionEnCurso = null;
      if (mounted && identical(_operacion, operacion)) {
        setState(() {
          _ocupado = false;
          _operacion = null;
        });
      }
    }
  }

  Future<void> _abrirEditor(
    XFile archivo,
    OperacionFotografia operacion,
    ProductorRepository repositorio, {
    required bool editar,
  }) async {
    final bytes = await archivo.readAsBytes();
    if (!mounted || !_esLaOperacionActual(operacion) || bytes.isEmpty) return;
    final elegido = PlatformFile(
      name: archivo.name.isEmpty
          ? 'foto-${DateTime.now().millisecondsSinceEpoch}.jpg'
          : archivo.name,
      size: bytes.length,
      bytes: bytes,
    );

    final resultado = await Navigator.of(context, rootNavigator: true)
        .push<ImagenSubida>(
          MaterialPageRoute<ImagenSubida>(
            builder: (context) => _VistaPrevia(
              archivo: elegido,
              editar: editar,
              destinatario: operacion.destinatario,
              verificarOperacion: operacion.verificarParaEnviar,
              guardar: (bytes, nombre) async {
                if (!_esLaOperacionActual(operacion)) operacion.cancelar();
                operacion.verificarParaEnviar();
                final respuesta = await repositorio.subirImagen(
                  productorId: operacion.productorId,
                  operacionId: operacion.id,
                  bytes: bytes,
                  nombreArchivo: nombre,
                );
                operacion.confirmar(respuesta);
                return respuesta;
              },
            ),
          ),
        );
    if (!mounted || resultado == null || !_esLaOperacionActual(operacion)) {
      return;
    }
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
  }

  Future<void> _borrar() async {
    if (!mounted || _ocupado || !widget.editable) return;
    final productorId = widget.productorId;
    setState(() => _ocupado = true);
    try {
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
      if (confirmado != true ||
          !mounted ||
          widget.productorId != productorId ||
          !widget.editable) {
        return;
      }

      await PadronScope.of(context).productores.eliminarImagen(productorId);
      if (!mounted || widget.productorId != productorId) return;
      widget.alCambiar();
    } catch (e) {
      if (mounted && widget.productorId == productorId) {
        mostrarError(context, e);
      }
    } finally {
      if (mounted && widget.productorId == productorId) {
        setState(() => _ocupado = false);
      }
    }
  }
}

/// Fotografía preparada por el editor. Al cancelar, la ruta devuelve null.
/// Editor a pantalla completa para preparar la fotografía antes de subirla.
class _VistaPrevia extends StatefulWidget {
  const _VistaPrevia({
    required this.archivo,
    required this.guardar,
    required this.destinatario,
    required this.verificarOperacion,
    this.editar = false,
  });

  final PlatformFile archivo;
  final bool editar;
  final String destinatario;
  final VoidCallback verificarOperacion;
  final Future<ImagenSubida> Function(Uint8List bytes, String nombre) guardar;

  @override
  State<_VistaPrevia> createState() => _VistaPreviaState();
}

class _VistaPreviaState extends State<_VistaPrevia> {
  Recorte? _recorte;
  bool _quitarFondo = true;
  bool _procesando = false;
  bool _terminada = false;
  bool _ajustandoRecorte = false;
  String? _errorPreparacion;
  static const _ladoMaximo = 600;

  @override
  void initState() {
    super.initState();
    _quitarFondo = !widget.editar;
  }

  bool get _esPng => widget.archivo.name.toLowerCase().endsWith('.png');
  bool get _soloRecortar => _esPng && !_quitarFondo;

  void _cancelar() {
    if (_procesando || _terminada || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final bytes = Uint8List.fromList(widget.archivo.bytes!);

    return PopScope(
      canPop: !_procesando,
      child: Scaffold(
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
                      widget.destinatario,
                      textAlign: TextAlign.center,
                      style: tema.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
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
                          if (!mounted || _ajustandoRecorte == ajustando) {
                            return;
                          }
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
                  onPressed: _procesando ? null : _cancelar,
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
                    label: Text(
                      _procesando ? 'Procesando…' : 'Procesar imagen',
                    ),
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
      ),
    );
  }

  Future<void> _preparar() async {
    if (_procesando || _terminada) return;
    try {
      widget.verificarOperacion();
    } catch (e) {
      setState(() => _errorPreparacion = '$e');
      return;
    }
    final recorte = _recorte;
    if (recorte == null) {
      setState(() => _errorPreparacion = 'Esperá a que cargue la fotografía.');
      return;
    }
    if (!_soloRecortar && !fondoIaDisponible) {
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
      final Uint8List preparada;
      if (_soloRecortar) {
        final origen = img.decodeImage(widget.archivo.bytes!);
        if (origen == null) throw StateError('No se pudo abrir la fotografía.');
        preparada = Uint8List.fromList(
          img.encodePng(
            img.copyCrop(
              origen,
              x: recorte.x,
              y: recorte.y,
              width: recorte.ancho,
              height: recorte.alto,
            ),
          ),
        );
      } else {
        final resultado = await prepararFotoSinFondo(
          bytes: Uint8List.fromList(widget.archivo.bytes!),
          recorte: recorte,
          quitarFondo: !_soloRecortar,
          tipoMime: _tipoMime(),
        );
        preparada = resultado.bytes;
      }
      final imagen = img.decodePng(preparada)!;
      final salida = imagen.width <= _ladoMaximo && imagen.height <= _ladoMaximo
          ? preparada
          : Uint8List.fromList(
              img.encodePng(
                img.copyResize(
                  imagen,
                  width: _ladoMaximo,
                  height: _ladoMaximo,
                  interpolation: img.Interpolation.cubic,
                ),
              ),
            );
      if (!mounted) return;
      widget.verificarOperacion();
      final guardada = await showDialog<ImagenSubida>(
        context: context,
        barrierDismissible: false,
        builder: (context) => ConfirmarSubidaFoto(
          bytes: salida,
          destinatario: widget.destinatario,
          guardar: () => widget.guardar(salida, _nombrePng()),
        ),
      );
      if (!mounted || guardada == null) return;
      setState(() {
        _terminada = true;
        _procesando = false;
      });
      // PopScope debe haberse reconstruido antes de cerrar programáticamente.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final ruta = ModalRoute.of(context)!;
      final navegador = Navigator.of(context);
      if (ruta.isCurrent) {
        navegador.pop(guardada);
      } else {
        navegador.removeRoute(ruta, guardada);
      }
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

class ConfirmarSubidaFoto extends StatefulWidget {
  const ConfirmarSubidaFoto({
    super.key,
    required this.bytes,
    required this.guardar,
    this.destinatario,
  });
  final Uint8List bytes;
  final Future<ImagenSubida> Function() guardar;
  final String? destinatario;
  @override
  State<ConfirmarSubidaFoto> createState() => _ConfirmarSubidaState();
}

class _ConfirmarSubidaState extends State<ConfirmarSubidaFoto> {
  bool _subiendo = false;
  bool _confirmada = false;
  String? _error;
  void _atras() {
    if (_subiendo || _confirmada || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
  }

  Future<void> _subir() async {
    if (_subiendo || _confirmada) return;
    setState(() {
      _subiendo = true;
      _error = null;
    });
    try {
      final respuesta = await widget.guardar();
      if (!mounted) return;
      setState(() {
        _confirmada = true;
        _subiendo = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final ruta = ModalRoute.of(context)!;
      final navegador = Navigator.of(context);
      if (ruta.isCurrent) {
        navegador.pop(respuesta);
      } else {
        navegador.removeRoute(ruta, respuesta);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _subiendo = false;
          _error =
              'No se pudo confirmar la subida. La imagen se conserva; podés reintentar.\n$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_subiendo,
    child: AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vista previa'),
          if (widget.destinatario != null)
            Text(
              widget.destinatario!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
      scrollable: true,
      content: SizedBox(
        width: 420,
        height: (MediaQuery.sizeOf(context).height * .5).clamp(1, 420),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            children: [
              Expanded(child: Image.memory(widget.bytes, fit: BoxFit.contain)),
              if (_subiendo) const LinearProgressIndicator(),
              if (_subiendo)
                const Text('Subiendo… esperando confirmación del servidor.'),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _subiendo || _confirmada ? null : _atras,
          child: const Text('Atrás'),
        ),
        FilledButton(
          onPressed: _subiendo || _confirmada ? null : _subir,
          child: Text(_error == null ? 'Subir' : 'Reintentar subida'),
        ),
      ],
    ),
  );
}
