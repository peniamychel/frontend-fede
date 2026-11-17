import '../imagen_autenticada.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../../core/fondo_ia.dart';
import '../../core/foto_pendiente.dart';
import '../../core/ajustes_fotografia.dart';
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
    this.borrable = true,
    this.nombreProductor,
    this.ci,
    this.enFicha = false,
    this.compacta = false,
    this.anchoFoto = 160,
    this.accionesAlLado = false,
  });

  final int productorId;

  /// Las variantes que hay guardadas. Vienen del backend, no se eligen.
  final List<Imagen> imagenes;

  final VoidCallback alCambiar;
  final bool editable;
  final bool borrable;
  final String? nombreProductor;
  final String? ci;
  final bool enFicha;
  final bool compacta;
  final double anchoFoto;
  final bool accionesAlLado;

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

    Widget retrato(double ancho) => SizedBox(
      width: ancho,
      child: AspectRatio(
        aspectRatio: widget.enFicha ? 1 : 3 / 4,
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
    );

    if (widget.enFicha) {
      return ZonaSoltarArchivos(
        habilitada: widget.editable && !_ocupado,
        extensionesPermitidas: extensionesImagen,
        alSoltar: (archivos) => _previsualizarYSubir(archivos.first),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.accionesAlLado)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  retrato(widget.anchoFoto),
                  if (widget.editable) ...[
                    const SizedBox(width: 4),
                    _acciones(context, foto, compactas: true, verticales: true),
                  ],
                ],
              )
            else
              retrato(widget.anchoFoto),
            if (widget.editable && !widget.accionesAlLado) ...[
              const SizedBox(height: 4),
              _acciones(context, foto, compactas: widget.compacta),
            ],
            if (foto?.pendienteEdicion ?? false)
              Text(
                'Fotografía pendiente de edición',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.error,
                ),
              ),
            if (!widget.compacta && foto != null) ...[
              _dato(
                context,
                'Foto',
                '${foto.dimensiones} · ${foto.tamanoLegible}',
              ),
              if (foto.nombreOriginal != null)
                _dato(context, 'Archivo', foto.nombreOriginal!),
              if (foto.actualizadaEn != null)
                _dato(context, 'Última subida', _fecha(foto.actualizadaEn!)),
            ],
          ],
        ),
      );
    }

    return ZonaSoltarArchivos(
      habilitada: widget.editable && !_ocupado,
      extensionesPermitidas: extensionesImagen,
      alSoltar: (archivos) => _previsualizarYSubir(archivos.first),
      child: LayoutBuilder(
        builder: (context, limites) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            retrato(
              math.min(
                MediaQuery.sizeOf(context).height < 450 ? 96 : 160,
                limites.maxWidth * .38,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _detalle(context, foto)),
          ],
        ),
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
          if (foto.pendienteEdicion)
            Text(
              'Pendiente de edición · Impresión bloqueada',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.error,
              ),
            ),
          const SizedBox(height: 6),
          _dato(context, 'Foto', '${foto.dimensiones} · ${foto.tamanoLegible}'),
          if (foto.nombreOriginal != null)
            _dato(context, 'Archivo', foto.nombreOriginal!),
          if (foto.actualizadaEn != null)
            _dato(context, 'Última subida', _fecha(foto.actualizadaEn!)),
        ],
        const SizedBox(height: 12),
        if (widget.editable) _acciones(context, foto),
        if (widget.editable) const AyudaArrastrarArchivo(),
      ],
    );
  }

  Widget _acciones(
    BuildContext context,
    Imagen? foto, {
    bool compactas = false,
    bool verticales = false,
  }) {
    final tema = Theme.of(context);
    if (compactas) {
      return IconButtonTheme(
        data: const IconButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(40, 40)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: WidgetStatePropertyAll(EdgeInsets.all(8)),
          ),
        ),
        child: Flex(
          direction: verticales ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: foto == null ? 'Subir foto' : 'Reemplazar',
              onPressed: _ocupado ? null : _elegirYSubir,
              icon: Icon(
                foto == null ? Icons.add_a_photo_outlined : Icons.swap_horiz,
                size: 18,
              ),
            ),
            if (foto != null)
              IconButton(
                tooltip: 'Editar fotografía',
                onPressed: _ocupado ? null : _editar,
                icon: const Icon(Icons.crop, size: 18),
              ),
            if (foto != null && widget.borrable)
              IconButton(
                tooltip: 'Borrar fotografía',
                onPressed: _ocupado ? null : _borrar,
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: tema.colorScheme.error,
                ),
              ),
          ],
        ),
      );
    }
    return Wrap(
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
        if (foto != null && widget.borrable)
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
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
        detalles: foto,
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
          ImagenAutenticada(
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
        name: archivo.nombreArchivo,
        mimeType: archivo.tipoMime,
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
            builder: (context) => RecortarFotoProductorPagina(
              archivo: elegido,
              editar: editar,
              requiereProcesamiento:
                  editar && (_original?.pendienteEdicion ?? false),
              destinatario: operacion.destinatario,
              verificarOperacion: operacion.verificarParaEnviar,
              guardar: (bytes, nombre, pendienteEdicion) async {
                if (!_esLaOperacionActual(operacion)) operacion.cancelar();
                operacion.verificarParaEnviar();
                final respuesta = await repositorio.subirImagen(
                  productorId: operacion.productorId,
                  operacionId: operacion.id,
                  bytes: bytes,
                  nombreArchivo: nombre,
                  pendienteEdicion: pendienteEdicion,
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
      resultado.original.pendienteEdicion
          ? 'Foto guardada, pendiente de edición'
          : 'Foto guardada',
      detalle: resultado.huboReduccion
          ? 'De ${pesoLegible(resultado.tamanoSubidoBytes)} a '
                '${pesoLegible(resultado.original.tamanoBytes)}, '
                '${resultado.porcentajeReduccion} % menos.'
          : null,
    );
    widget.alCambiar();
  }

  Future<void> _borrar() async {
    if (!mounted || _ocupado || !widget.editable || !widget.borrable) return;
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
          !widget.editable ||
          !widget.borrable) {
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
class RecortarFotoProductorPagina extends StatefulWidget {
  const RecortarFotoProductorPagina({
    super.key,
    required this.archivo,
    required this.guardar,
    required this.destinatario,
    required this.verificarOperacion,
    this.editar = false,
    this.requiereProcesamiento = false,
  });

  final PlatformFile archivo;
  final bool editar;
  final bool requiereProcesamiento;
  final String destinatario;
  final VoidCallback verificarOperacion;
  final Future<ImagenSubida> Function(
    Uint8List bytes,
    String nombre,
    bool pendienteEdicion,
  )
  guardar;

  @override
  State<RecortarFotoProductorPagina> createState() => _VistaPreviaState();
}

enum _AccionFotografia { procesar, subirSinProcesar }

class _VistaPreviaState extends State<RecortarFotoProductorPagina> {
  Recorte? _recorte;
  bool _quitarFondo = true;
  _AccionFotografia? _accion;
  bool _terminada = false;
  bool _ajustandoRecorte = false;
  bool _ajustesAbiertos = true;
  final _claveRecortador = GlobalKey();
  String? _errorPreparacion;
  static const _ladoMaximo = 600;
  late final Uint8List _bytesOriginales;
  AjustesFotografia _ajustes = const AjustesFotografia();
  Uint8List? _vistaAjustada;
  Future<Uint8List>? _baseAjustes;
  Timer? _esperaAjustes;
  int _versionAjustes = 0;
  bool _actualizandoVista = false;
  String? _errorAjustes;

  bool get _procesando => _accion != null;

  @override
  void initState() {
    super.initState();
    _quitarFondo = !widget.editar || widget.requiereProcesamiento;
    _bytesOriginales = Uint8List.fromList(widget.archivo.bytes!);
  }

  @override
  void dispose() {
    _esperaAjustes?.cancel();
    super.dispose();
  }

  void _cambiarAjustes(AjustesFotografia ajustes) {
    if (_procesando) return;
    _esperaAjustes?.cancel();
    setState(() {
      _ajustes = ajustes;
      _versionAjustes++;
      _errorAjustes = null;
      if (!ajustes.modificados) _vistaAjustada = null;
    });
    if (ajustes.modificados) {
      _esperaAjustes = Timer(
        const Duration(milliseconds: 220),
        _actualizarVistaPrevia,
      );
    }
  }

  Future<void> _actualizarVistaPrevia() async {
    if (!mounted || _actualizandoVista || _procesando) return;
    setState(() => _actualizandoVista = true);
    var version = _versionAjustes;
    try {
      while (mounted) {
        version = _versionAjustes;
        final ajustes = _ajustes;
        if (!ajustes.modificados) break;
        final base = await (_baseAjustes ??= compute(
          prepararBaseAjustesFotografia,
          _bytesOriginales,
        ));
        if (!mounted) return;
        if (version != _versionAjustes) continue;
        final resultado = await compute(
          aplicarAjustesFotografia,
          SolicitudAjustesFotografia(base, ajustes),
        );
        if (!mounted) return;
        if (version != _versionAjustes) continue;
        setState(() => _vistaAjustada = resultado);
        break;
      }
    } catch (_) {
      _baseAjustes = null;
      if (mounted && version == _versionAjustes) {
        setState(
          () => _errorAjustes =
              'No se pudo actualizar la vista previa. '
              'Vuelve a ajustar o restablece los cambios.',
        );
      }
    } finally {
      if (mounted) setState(() => _actualizandoVista = false);
    }
  }

  double _altoControl(BuildContext context) => math.max(
    MediaQuery.sizeOf(context).height < 700 ? 28 : 36,
    MediaQuery.textScalerOf(context).scale(14) + 8,
  );

  double _altoCabeceraAjustes(BuildContext context) => math.max(
    MediaQuery.sizeOf(context).height < 700 ? 28 : 36,
    MediaQuery.textScalerOf(context).scale(16) + 8,
  );

  Widget _controlesAjustes(BuildContext context, {bool lateral = false}) {
    final controles = [
      _controlAjuste(
        'Brillo',
        _ajustes.brillo,
        -0.5,
        0.5,
        (v) => _cambiarAjustes(_ajustes.copiar(brillo: v)),
      ),
      _controlAjuste(
        'Contraste',
        _ajustes.contraste,
        -0.5,
        0.5,
        (v) => _cambiarAjustes(_ajustes.copiar(contraste: v)),
      ),
      _controlAjuste(
        'Saturación',
        _ajustes.saturacion,
        -1,
        1,
        (v) => _cambiarAjustes(_ajustes.copiar(saturacion: v)),
      ),
      _controlAjuste(
        'Nitidez',
        _ajustes.nitidez,
        0,
        1,
        (v) => _cambiarAjustes(_ajustes.copiar(nitidez: v)),
      ),
    ];
    return Card(
      key: const ValueKey('ajustes-fotografia'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: lateral ? MainAxisSize.max : MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _ajustesAbiertos = !_ajustesAbiertos),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: _altoCabeceraAjustes(context),
                child: Row(
                  children: [
                    const Icon(Icons.tune, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ajustes de imagen',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Icon(
                      _ajustesAbiertos ? Icons.expand_less : Icons.expand_more,
                      semanticLabel: _ajustesAbiertos
                          ? 'Ocultar ajustes'
                          : 'Mostrar ajustes',
                    ),
                  ],
                ),
              ),
            ),
            if (_ajustesAbiertos) ...[
              if (lateral)
                Expanded(
                  child: Column(
                    children: [
                      for (final control in controles) Expanded(child: control),
                    ],
                  ),
                )
              else
                for (final control in controles)
                  SizedBox(height: _altoControl(context), child: control),
              SizedBox(
                height: _altoControl(context),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _procesando || !_ajustes.modificados
                        ? null
                        : () => _cambiarAjustes(const AjustesFotografia()),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Restablecer ajustes'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(
              height: 2,
              child: _actualizandoVista
                  ? const LinearProgressIndicator()
                  : null,
            ),
            if (_errorAjustes != null)
              Tooltip(
                message: _errorAjustes!,
                child: Text(
                  _errorAjustes!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controlAjuste(
    String nombre,
    double valor,
    double minimo,
    double maximo,
    ValueChanged<double> cambiar,
  ) {
    final porcentaje = (valor * 100).round();
    final etiqueta = '${porcentaje > 0 ? '+' : ''}$porcentaje %';
    final deslizador = Slider(
      key: ValueKey('ajuste-$nombre'),
      value: valor,
      min: minimo,
      max: maximo,
      divisions: ((maximo - minimo) * 100).round(),
      label: etiqueta,
      onChanged: _procesando ? null : cambiar,
      onChangeEnd: _procesando
          ? null
          : (_) {
              _esperaAjustes?.cancel();
              _actualizarVistaPrevia();
            },
    );
    final titulo = Text(
      nombre,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    );
    final valorTexto = Text(
      etiqueta,
      maxLines: 1,
      style: Theme.of(context).textTheme.bodySmall,
    );
    return LayoutBuilder(
      builder: (context, limites) {
        if (limites.maxHeight >= 80) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(children: [titulo, const Spacer(), valorTexto]),
              deslizador,
            ],
          );
        }
        return Row(
          children: [
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(68),
              child: titulo,
            ),
            Expanded(child: deslizador),
            SizedBox(
              width: MediaQuery.textScalerOf(context).scale(44),
              child: Align(alignment: Alignment.centerRight, child: valorTexto),
            ),
          ],
        );
      },
    );
  }

  bool get _esPng => widget.archivo.name.toLowerCase().endsWith('.png');
  bool get _soloRecortar => _esPng && !_quitarFondo;

  void _cancelar() {
    if (_procesando || _terminada || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent ?? false) Navigator.of(context).pop();
  }

  Widget _recortador({bool mostrarControles = true}) => AbsorbPointer(
    absorbing: _procesando,
    child: RecortadorImagen(
      key: _claveRecortador,
      bytes: _bytesOriginales,
      bytesVistaPrevia: _vistaAjustada,
      expandir: true,
      mostrarControles: mostrarControles,
      proporcionFija: Proporcion.cuadrada,
      alCambiar: (recorte) {
        if (!mounted) return;
        setState(() {
          _recorte = recorte;
          _errorPreparacion = null;
        });
      },
      alCambiarInteraccion: (ajustando) {
        if (!mounted || _ajustandoRecorte == ajustando) return;
        setState(() => _ajustandoRecorte = ajustando);
      },
    ),
  );

  Widget _editorAcotado(BuildContext context) => Center(
    child: ConstrainedBox(
      // Dos paneles de 400, separación de 16 y margen de 12 para las asas.
      constraints: const BoxConstraints(maxWidth: 840),
      child: LayoutBuilder(
        builder: (context, espacio) {
          final anchoPanel = math.min(400.0, (espacio.maxWidth - 40) / 2);
          return Column(
            key: const ValueKey('editor-foto-acotado'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cabeceraFoto(context, compacta: false),
              const SizedBox(height: 8),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, areaPaneles) {
                    final lado = math.min(
                      anchoPanel,
                      math.max(0.0, areaPaneles.maxHeight - 24),
                    );
                    return SizedBox(
                      height: lado + 24,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox.square(
                            dimension: lado + 24,
                            child: _recortador(mostrarControles: false),
                          ),
                          const SizedBox(width: 16),
                          SizedBox.square(
                            dimension: lado,
                            child: _controlesAjustes(context, lateral: true),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      'Formato de fotografía: cuadrado (1:1)',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: anchoPanel,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_esPng) _opcionFondo(context),
                        _avisoPreparacion(context),
                        _accionesEditor(context),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_procesando,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recortar y subir'),
          toolbarHeight: MediaQuery.sizeOf(context).height < 500 ? 48 : 56,
          actions: [
            Tooltip(
              message:
                  '${widget.archivo.name} · ${pesoLegible(widget.archivo.size)}',
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Icon(Icons.photo_outlined),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, limites) {
              if (limites.maxWidth >= 700 && limites.maxHeight >= 480) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: _editorAcotado(context),
                );
              }
              final lateral =
                  limites.maxWidth >= 900 ||
                  (limites.maxWidth >= 560 &&
                      limites.maxWidth > limites.maxHeight);
              final foto = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _cabeceraFoto(context, compacta: limites.maxHeight < 560),
                  const SizedBox(height: 4),
                  Expanded(child: _recortador()),
                ],
              );
              return Padding(
                padding: const EdgeInsets.all(8),
                child: lateral
                    ? Row(
                        key: const ValueKey('editor-foto-horizontal'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: foto),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: math.min(
                              400,
                              (limites.maxWidth - 32) * 0.48,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _controlesAjustes(
                                    context,
                                    lateral: true,
                                  ),
                                ),
                                if (_esPng) _opcionFondo(context),
                                _avisoPreparacion(context),
                                _accionesEditor(context),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('editor-foto-vertical'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: foto),
                          if (_esPng) _opcionFondo(context),
                          const SizedBox(height: 4),
                          _controlesAjustes(context),
                          _avisoPreparacion(context),
                          _accionesEditor(context),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cabeceraFoto(BuildContext context, {required bool compacta}) {
    final tema = Theme.of(context);
    return Column(
      children: [
        Tooltip(
          message: widget.destinatario,
          child: Text(
            widget.destinatario,
            textAlign: TextAlign.center,
            maxLines: compacta ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: tema.textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          compacta
              ? 'Centra cabeza y hombros dentro del cuadro.'
              : 'Acomoda cabeza y hombros dentro del cuadro. La foto se guardará cuadrada.',
          maxLines: compacta ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _opcionFondo(BuildContext context) => Tooltip(
    message: _quitarFondo
        ? 'Conserva automáticamente a la persona y guarda PNG transparente.'
        : 'Sin quitar el fondo, la fotografía nueva seguirá pendiente de edición.',
    child: SizedBox(
      height: math.max(
        MediaQuery.sizeOf(context).height < 700 ? 36 : 40,
        _altoControl(context),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        dense: true,
        visualDensity: VisualDensity.compact,
        value: _quitarFondo,
        onChanged: _procesando
            ? null
            : (valor) => setState(() {
                _quitarFondo = valor;
                _errorPreparacion = null;
              }),
        title: const Text('Quitar fondo'),
      ),
    ),
  );

  Widget _avisoPreparacion(BuildContext context) {
    if (_errorPreparacion == null) return const SizedBox(height: 4);
    return Tooltip(
      message: _errorPreparacion!,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          _errorPreparacion!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }

  Widget _accionesEditor(BuildContext context) => Row(
    children: [
      Expanded(
        flex: 3,
        child: FilledButton(
          key: const ValueKey('procesar-fotografia'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          ),
          onPressed: _procesando || _ajustandoRecorte || _recorte == null
              ? null
              : () => _preparar(),
          child: Text(
            _accion == _AccionFotografia.procesar
                ? 'Procesando…'
                : 'Procesar imagen',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        flex: 2,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          onPressed: _procesando ? null : _cancelar,
          child: const Text('Cancelar'),
        ),
      ),
      if (!widget.editar || widget.requiereProcesamiento) ...[
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: OutlinedButton(
            key: const ValueKey('subir-fotografia-sin-procesar'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            ),
            onPressed: _procesando || _ajustandoRecorte || _recorte == null
                ? null
                : () => _preparar(sinProcesar: true),
            child: Text(
              _accion == _AccionFotografia.subirSinProcesar
                  ? 'Subiendo…'
                  : 'Subir sin procesar',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ],
  );
  Future<void> _preparar({bool sinProcesar = false}) async {
    if (_procesando || _terminada) return;
    try {
      widget.verificarOperacion();
    } catch (e) {
      setState(() => _errorPreparacion = '$e');
      return;
    }
    final recorte = _recorte;
    if (recorte == null) {
      setState(() => _errorPreparacion = 'Espera a que cargue la fotografía.');
      return;
    }
    if (!sinProcesar && !_soloRecortar && !fondoIaDisponible) {
      setState(
        () => _errorPreparacion =
            'La eliminación de fondo está disponible por ahora en la versión web.',
      );
      return;
    }

    setState(() {
      _accion = sinProcesar
          ? _AccionFotografia.subirSinProcesar
          : _AccionFotografia.procesar;
      _errorPreparacion = null;
    });
    _esperaAjustes?.cancel();
    try {
      Uint8List salida;
      if (sinProcesar) {
        salida = await compute(
          prepararFotoPendiente,
          SolicitudFotoPendiente(_bytesOriginales, recorte, _ajustes),
        );
      } else if (_soloRecortar) {
        final decodificada = img.decodeImage(_bytesOriginales);
        if (decodificada == null) {
          throw StateError('No se pudo abrir la fotografía.');
        }
        final imagen = img.copyCrop(
          img.bakeOrientation(decodificada),
          x: recorte.x,
          y: recorte.y,
          width: recorte.ancho,
          height: recorte.alto,
        );
        salida = imagen.width <= _ladoMaximo && imagen.height <= _ladoMaximo
            ? Uint8List.fromList(img.encodePng(imagen))
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
        if (_ajustes.modificados) {
          salida = await compute(
            aplicarAjustesFotografia,
            SolicitudAjustesFotografia(salida, _ajustes),
          );
        }
      } else {
        salida = await procesarFotoProductor(
          bytes: _bytesOriginales,
          recorte: recorte,
          tipoMime: _tipoMime(),
          ajustes: _ajustes,
        );
      }
      if (!mounted) return;
      widget.verificarOperacion();
      final pendiente =
          sinProcesar ||
          (_soloRecortar && (!widget.editar || widget.requiereProcesamiento));
      final nombre = sinProcesar
          ? '${_nombrePng().replaceFirst(RegExp(r'\.png$'), '')}.jpg'
          : _nombrePng();
      final guardada = sinProcesar
          ? await widget.guardar(salida, nombre, pendiente)
          : await showDialog<ImagenSubida>(
              context: context,
              barrierDismissible: false,
              builder: (context) => ConfirmarSubidaFoto(
                bytes: salida,
                destinatario: widget.destinatario,
                pendienteEdicion: pendiente,
                guardar: () => widget.guardar(salida, nombre, pendiente),
              ),
            );
      if (!mounted || guardada == null) return;
      setState(() {
        _terminada = true;
        _accion = null;
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
      if (mounted && _accion != null) setState(() => _accion = null);
      if (mounted && !_terminada && _ajustes.modificados) {
        _actualizarVistaPrevia();
      }
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
    this.pendienteEdicion = false,
  });
  final Uint8List bytes;
  final Future<ImagenSubida> Function() guardar;
  final String? destinatario;
  final bool pendienteEdicion;
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
          if (widget.pendienteEdicion)
            Text(
              'Pendiente de edición. Quitá el fondo antes de imprimir.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
