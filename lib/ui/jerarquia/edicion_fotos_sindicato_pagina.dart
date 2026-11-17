import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/ajustes_fotografia.dart';
import '../../core/fondo_ia.dart';
import '../../core/foto_pendiente.dart';
import '../../core/operacion_fotografia.dart';
import '../../core/portapapeles_imagen.dart';
import '../../repositories/padron.dart';
import '../imagen_autenticada.dart';
import '../padron_scope.dart';
import '../productores/imagenes_productor.dart';
import '../productores/recortador_imagen.dart';
import '../sesion_scope.dart';
import '../widgets/estados.dart';

enum _CambiosPendientes { descartar, guardar }

typedef _FotoEditable = ({
  Productor productor,
  String original,
  String miniatura,
  bool pendienteEdicion,
});

class EdicionFotosSindicatoPagina extends StatefulWidget {
  const EdicionFotosSindicatoPagina({
    super.key,
    required this.sindicato,
    this.procesarFoto = procesarFotoProductor,
    this.selectorImagenes,
  });

  final Sindicato sindicato;
  final ImagePicker? selectorImagenes;
  final Future<Uint8List> Function({
    required Uint8List bytes,
    required Recorte recorte,
    required String tipoMime,
    required AjustesFotografia ajustes,
  })
  procesarFoto;

  @override
  State<EdicionFotosSindicatoPagina> createState() =>
      _EdicionFotosSindicatoPaginaState();
}

class _EdicionFotosSindicatoPaginaState
    extends State<EdicionFotosSindicatoPagina> {
  static const double _anchoMiniatura = 76;
  final _cinta = ScrollController();
  late final _selectorImagenes = widget.selectorImagenes ?? ImagePicker();
  List<_FotoEditable> _fotos = [];
  int _indice = 0;
  bool _cargando = true;
  bool _guardando = false;
  bool _reemplazando = false;
  bool _preguntando = false;
  bool _guardadas = false;
  bool _compararOriginal = false;
  Object? _errorLista;
  Future<Uint8List>? _foto;
  Recorte? _recorte;
  Recorte? _recorteInicial;
  bool _recortando = false;
  GlobalKey _claveRecortador = GlobalKey();
  AjustesFotografia _ajustes = const AjustesFotografia();
  Future<Uint8List>? _baseAjustes;
  Uint8List? _vistaAjustada;
  Timer? _esperaAjustes;
  bool _calculandoVista = false;
  int _versionAjustes = 0;
  Object? _errorVista;

  bool get _esAdministrador =>
      SesionScope.maybeOf(context)?.sesion?.esAdministrador == true;

  bool get _hayCambios =>
      _ajustes.modificados ||
      _recorte?.x != _recorteInicial?.x ||
      _recorte?.y != _recorteInicial?.y ||
      _recorte?.ancho != _recorteInicial?.ancho ||
      _recorte?.alto != _recorteInicial?.alto;

  bool get _ocupado => _guardando || _preguntando || _reemplazando;

  bool get _requiereProcesamiento {
    final actual = _fotos[_indice];
    return actual.pendienteEdicion || _esJpeg(actual.original);
  }

  bool _esJpeg(String url) {
    final ruta = Uri.parse(url).path.toLowerCase();
    return ruta.endsWith('.jpg') || ruta.endsWith('.jpeg');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _esAdministrador) unawaited(_cargar());
    });
  }

  @override
  void dispose() {
    _esperaAjustes?.cancel();
    _cinta.dispose();
    super.dispose();
  }

  Future<void> _cargar({int? conservarProductor}) async {
    if (!_esAdministrador) return;
    final repositorio = PadronScope.of(context).productores;
    setState(() {
      _cargando = true;
      _errorLista = null;
      _foto = null;
      _calculandoVista = false;
      _restablecerEdicion();
    });
    try {
      final fotos = <_FotoEditable>[];
      final vistos = <int>{};
      for (var pagina = 0; ; pagina++) {
        final resultado = await repositorio.listar(
          sindicatoId: widget.sindicato.id,
          orden: OrdenProductores.apellidos,
          paginacion: Paginacion(pagina: pagina, tamano: 100),
        );
        if (!mounted) return;
        for (final productor in resultado.contenido) {
          final original = productor.fotoUrl;
          if (original != null &&
              original.isNotEmpty &&
              vistos.add(productor.id)) {
            fotos.add((
              productor: productor,
              original: original,
              miniatura: productor.miniaturaUrl ?? original,
              pendienteEdicion: productor.fotografiaPendienteEdicion,
            ));
          }
        }
        if (resultado.esUltima || resultado.estaVacia) break;
      }
      final elegido = fotos.indexWhere(
        (f) => f.productor.id == conservarProductor,
      );
      setState(() {
        _fotos = fotos;
        _cargando = false;
        if (fotos.isNotEmpty) _mostrar(elegido < 0 ? 0 : elegido);
      });
      _centrarMiniatura();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorLista = error;
        _cargando = false;
      });
    }
  }

  void _restablecerEdicion() {
    _esperaAjustes?.cancel();
    _versionAjustes++;
    _claveRecortador = GlobalKey();
    _recorte = null;
    _recorteInicial = null;
    _recortando = false;
    _ajustes = const AjustesFotografia();
    _vistaAjustada = null;
    _errorVista = null;
  }

  void _mostrar(int indice) {
    _indice = indice;
    _compararOriginal = false;
    _baseAjustes = null;
    _calculandoVista = false;
    _restablecerEdicion();
    _foto = _descargar(_fotos[indice].original);
  }

  Future<Uint8List> _descargar(String url) async {
    final archivo = await PadronScope.of(
      context,
    ).api.descargarUrl(Uri.parse(ApiConfig.urlAbsoluta(url)));
    return Uint8List.fromList(archivo.bytes);
  }

  void _centrarMiniatura() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_cinta.hasClients) return;
      final posicion = _cinta.position;
      final destino =
          (_anchoMiniatura * (_indice + .5) - posicion.viewportDimension / 2)
              .clamp(0.0, posicion.maxScrollExtent);
      unawaited(
        _cinta.animateTo(
          destino,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  Future<bool> _resolverCambiosPendientes({
    bool ofrecerProcesamiento = true,
  }) async {
    if (_ocupado) return false;
    final hayCambios = _hayCambios;
    final procesar = _recorte != null && _requiereProcesamiento;
    if (!hayCambios && !(procesar && ofrecerProcesamiento)) return true;
    setState(() => _preguntando = true);
    final _CambiosPendientes? decision;
    try {
      decision = await showDialog<_CambiosPendientes>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            hayCambios ? '¿Descartar los cambios?' : '¿Procesar esta foto?',
          ),
          content: Text(
            hayCambios
                ? 'La edición de esta foto todavía no está guardada.'
                : 'Podés quitar el fondo y guardar la foto antes de continuar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _CambiosPendientes.descartar),
              child: Text(hayCambios ? 'Descartar' : 'Omitir'),
            ),
            FilledButton(
              autofocus: true,
              onPressed: () =>
                  Navigator.pop(context, _CambiosPendientes.guardar),
              child: Text(procesar ? 'Procesar y guardar' : 'Guardar cambios'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _preguntando = false);
    }
    if (!mounted) return false;
    return switch (decision) {
      _CambiosPendientes.descartar => true,
      _CambiosPendientes.guardar => await _guardar(),
      null => false,
    };
  }

  Future<void> _irA(int indice) async {
    if (_cargando ||
        _errorLista != null ||
        _recortando ||
        indice == _indice ||
        indice < 0 ||
        indice >= _fotos.length) {
      return;
    }
    if (!await _resolverCambiosPendientes() || !mounted || !_esAdministrador) {
      return;
    }
    setState(() => _mostrar(indice));
    _centrarMiniatura();
  }

  Future<void> _salir() async {
    if (!await _resolverCambiosPendientes() || !mounted) return;
    Navigator.of(context).pop(_guardadas);
  }

  Future<void> _recargarFoto() async {
    if (!await _resolverCambiosPendientes() || !mounted) return;
    await _cargar(conservarProductor: _fotos[_indice].productor.id);
  }

  void _abrirMenuOriginal(Offset posicion, Uint8List bytes) {
    if (_ocupado) return;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final punto = overlay.globalToLocal(posicion);
    unawaited(
      showMenu<void>(
        context: context,
        position: RelativeRect.fromSize(punto & Size.zero, overlay.size),
        items: [
          PopupMenuItem<void>(
            onTap: () => unawaited(_copiarOriginal(bytes)),
            child: const Text('Copiar imagen'),
          ),
          PopupMenuItem<void>(
            onTap: () => unawaited(_reemplazarFoto()),
            child: const Text('Reemplazar imagen'),
          ),
        ],
      ),
    );
  }

  Future<void> _copiarOriginal(Uint8List bytes) async {
    try {
      await copiarImagenPortapapeles(bytes);
      if (mounted) mostrarExito(context, 'Imagen copiada');
    } catch (error) {
      if (mounted) mostrarError(context, error);
    }
  }

  Future<void> _reemplazarFoto() async {
    if (_ocupado || _recortando || !_esAdministrador) return;
    if (!await _resolverCambiosPendientes(ofrecerProcesamiento: false) ||
        !mounted ||
        !_esAdministrador) {
      return;
    }
    final actual = _fotos[_indice];
    final repositorio = PadronScope.of(context).productores;
    final operacion = OperacionFotografia(
      productorId: actual.productor.id,
      nombre: actual.productor.nombreCompleto,
      ci: actual.productor.ci,
    );
    setState(() => _reemplazando = true);
    try {
      final elegida = await _selectorImagenes.pickImage(
        source: ImageSource.gallery,
      );
      if (elegida == null || !mounted || !_esAdministrador) return;
      final bytes = await elegida.readAsBytes();
      if (!mounted || !_esAdministrador) return;
      if (bytes.isEmpty) throw StateError('El archivo de imagen está vacío.');

      final guardada = await Navigator.of(context, rootNavigator: true)
          .push<ImagenSubida>(
            MaterialPageRoute<ImagenSubida>(
              builder: (context) => RecortarFotoProductorPagina(
                archivo: PlatformFile(
                  name: elegida.name,
                  size: bytes.length,
                  bytes: bytes,
                ),
                destinatario: operacion.destinatario,
                verificarOperacion: operacion.verificarParaEnviar,
                guardar: (bytes, nombre, pendienteEdicion) async {
                  if (!mounted || !_esAdministrador) operacion.cancelar();
                  operacion.verificarParaEnviar();
                  final respuesta = await repositorio.subirImagen(
                    productorId: operacion.productorId,
                    bytes: bytes,
                    nombreArchivo: nombre,
                    operacionId: operacion.id,
                    pendienteEdicion: pendienteEdicion,
                    fotoOrigen: actual.original,
                  );
                  operacion.confirmar(respuesta);
                  return respuesta;
                },
              ),
            ),
          );
      if (!mounted || guardada == null) return;
      setState(() {
        _registrarFotoGuardada(actual, guardada);
        _mostrar(_indice);
      });
      mostrarExito(
        context,
        guardada.original.pendienteEdicion
            ? 'Foto guardada, pendiente de edición'
            : 'Foto reemplazada',
      );
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      operacion.cancelar();
      if (mounted) setState(() => _reemplazando = false);
    }
  }

  void _registrarFotoGuardada(_FotoEditable actual, ImagenSubida guardada) {
    _guardadas = true;
    _fotos[_indice] = (
      productor: actual.productor,
      original: guardada.original.url,
      miniatura: guardada.miniatura.url,
      pendienteEdicion: guardada.original.pendienteEdicion,
    );
  }

  void _ajustar(Uint8List bytes, AjustesFotografia ajustes) {
    _esperaAjustes?.cancel();
    setState(() {
      _ajustes = ajustes;
      _versionAjustes++;
      _errorVista = null;
      if (!ajustes.modificados) _vistaAjustada = null;
    });
    if (ajustes.modificados) {
      _esperaAjustes = Timer(
        const Duration(milliseconds: 120),
        () => _actualizarVista(bytes),
      );
    }
  }

  Future<void> _actualizarVista(Uint8List bytes) async {
    if (_calculandoVista || _foto == null) return;
    _calculandoVista = true;
    final versionFoto = _foto;
    var version = _versionAjustes;
    try {
      while (mounted && _foto == versionFoto && _ajustes.modificados) {
        version = _versionAjustes;
        final ajustes = _ajustes;
        final base = await (_baseAjustes ??= compute(
          prepararBaseAjustesFotografia,
          bytes,
        ));
        if (!mounted || _foto != versionFoto) return;
        if (version != _versionAjustes) continue;
        final previa = await compute(
          aplicarAjustesFotografia,
          SolicitudAjustesFotografia(base, ajustes),
        );
        if (!mounted || _foto != versionFoto) return;
        if (version != _versionAjustes) continue;
        setState(() => _vistaAjustada = previa);
        return;
      }
    } catch (error) {
      if (mounted && _foto == versionFoto && version == _versionAjustes) {
        setState(() {
          _baseAjustes = null;
          _errorVista = error;
        });
      }
    } finally {
      if (_foto == versionFoto) _calculandoVista = false;
    }
  }

  Future<bool> _guardar() async {
    final recorte = _recorte;
    final foto = _foto;
    if (_ocupado ||
        _recortando ||
        recorte == null ||
        foto == null ||
        !_esAdministrador) {
      return false;
    }
    final actual = _fotos[_indice];
    final procesar = _requiereProcesamiento;
    final repositorio = PadronScope.of(context).productores;
    final operacion = OperacionFotografia(
      productorId: actual.productor.id,
      nombre: actual.productor.nombreCompleto,
    );
    final ajustes = _ajustes;
    setState(() => _guardando = true);
    try {
      final bytes = await foto;
      final editada = procesar
          ? await widget.procesarFoto(
              bytes: bytes,
              recorte: recorte,
              tipoMime: _esJpeg(actual.original) ? 'image/jpeg' : 'image/png',
              ajustes: ajustes,
            )
          : await compute(
              prepararEdicionManual,
              SolicitudFotoPendiente(bytes, recorte, ajustes),
            );
      if (!mounted || !_esAdministrador) return false;
      final guardada = await repositorio.guardarEdicionManual(
        productorId: operacion.productorId,
        bytes: editada,
        fotoOrigen: actual.original,
        operacionId: operacion.id,
        fondoProcesado: procesar,
      );
      if (!mounted) return false;
      setState(() => _registrarFotoGuardada(actual, guardada));
      mostrarExito(context, 'Foto guardada');
      return true;
    } catch (error) {
      if (mounted) mostrarError(context, error);
      return false;
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: false,
    onPopInvokedWithResult: (salio, _) {
      if (!salio) unawaited(_salir());
    },
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.arrowLeft,
          includeRepeats: false,
        ): () =>
            unawaited(_irA(_indice - 1)),
        const SingleActivator(
          LogicalKeyboardKey.arrowRight,
          includeRepeats: false,
        ): () =>
            unawaited(_irA(_indice + 1)),
      },
      child: FocusScope(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: _salir),
            title: const Text('Edición de fotos'),
            actions: [
              if (_esAdministrador && _fotos.isNotEmpty)
                IconButton(
                  tooltip: 'Recargar foto',
                  onPressed: _ocupado || _cargando ? null : _recargarFoto,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          body: SafeArea(child: _contenido()),
        ),
      ),
    ),
  );

  Widget _contenido() {
    if (!_esAdministrador) {
      return const SinResultados(
        mensaje: 'Disponible solo para administradores',
        icono: Icons.lock_outline,
      );
    }
    if (_cargando) return const Cargando(mensaje: 'Cargando fotografías…');
    if (_errorLista != null) {
      return FalloCarga(error: _errorLista!, alReintentar: _cargar);
    }
    if (_fotos.isEmpty) {
      return const SinResultados(
        mensaje: 'Este sindicato no tiene fotos cargadas',
        icono: Icons.photo_library_outlined,
      );
    }
    final productor = _fotos[_indice].productor;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Foto anterior',
                onPressed: _ocupado || _indice == 0
                    ? null
                    : () => _irA(_indice - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      productor.nombreCompleto,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${widget.sindicato.nombre} · ${_indice + 1} de ${_fotos.length}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (productor.ci?.isNotEmpty ?? false)
                      Text('CI: ${productor.ci}', maxLines: 1),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Foto siguiente',
                onPressed: _ocupado || _indice + 1 == _fotos.length
                    ? null
                    : () => _irA(_indice + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Uint8List>(
            key: ValueKey(_foto),
            future: _foto,
            builder: (context, estado) {
              if (estado.connectionState != ConnectionState.done) {
                return const Cargando();
              }
              if (estado.hasError) {
                return FalloCarga(
                  error: estado.error!,
                  alReintentar: _recargarFoto,
                );
              }
              final bytes = estado.data;
              return bytes == null ? const Cargando() : _editor(bytes);
            },
          ),
        ),
        const Divider(height: 1),
        SizedBox(height: 74, child: _miniaturas()),
      ],
    );
  }

  Widget _editor(Uint8List bytes) => LayoutBuilder(
    builder: (context, limites) {
      final enParalelo = limites.maxWidth >= 600;
      final alto = (limites.maxHeight - (enParalelo ? 290 : 335)).clamp(
        175.0,
        400.0,
      );
      final original = Center(
        child: Listener(
          onPointerDown: (evento) {
            if (!_ocupado && evento.buttons == kSecondaryMouseButton) {
              suprimirMenuNativoImagen();
            }
          },
          child: GestureDetector(
            key: const ValueKey('foto-original-sindicato'),
            behavior: HitTestBehavior.opaque,
            onSecondaryTapUp: (toque) =>
                _abrirMenuOriginal(toque.globalPosition, bytes),
            child: Image.memory(bytes, fit: BoxFit.contain),
          ),
        ),
      );
      final recortador = AbsorbPointer(
        absorbing: _ocupado,
        child: RecortadorImagen(
          key: _claveRecortador,
          bytes: bytes,
          bytesVistaPrevia: _vistaAjustada,
          expandir: true,
          mostrarControles: false,
          proporcionFija: Proporcion.cuadrada,
          alCambiar: (recorte) {
            if (!mounted) return;
            setState(() {
              _recorte = recorte;
              _recorteInicial ??= recorte;
            });
          },
          alCambiarInteraccion: (activo) =>
              setState(() => _recortando = activo),
        ),
      );
      final tema = Theme.of(context);
      return SingleChildScrollView(
        physics: _recortando ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!enParalelo)
                  Center(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Original')),
                        ButtonSegment(value: false, label: Text('Edición')),
                      ],
                      selected: {_compararOriginal},
                      onSelectionChanged: (v) =>
                          setState(() => _compararOriginal = v.single),
                    ),
                  ),
                SizedBox(
                  height: alto + 24,
                  child: enParalelo
                      ? Row(
                          children: [
                            Expanded(child: _panel('Original', original)),
                            const SizedBox(width: 12),
                            Expanded(child: _panel('Edición', recortador)),
                          ],
                        )
                      : IndexedStack(
                          index: _compararOriginal ? 0 : 1,
                          sizing: StackFit.expand,
                          children: [original, recortador],
                        ),
                ),
                const SizedBox(height: 6),
                _control(
                  'Brillo',
                  _ajustes.brillo,
                  -.5,
                  .5,
                  (v) => _ajustar(bytes, _ajustes.copiar(brillo: v)),
                ),
                _control(
                  'Contraste',
                  _ajustes.contraste,
                  -.5,
                  .5,
                  (v) => _ajustar(bytes, _ajustes.copiar(contraste: v)),
                ),
                _control(
                  'Saturación',
                  _ajustes.saturacion,
                  -1,
                  1,
                  (v) => _ajustar(bytes, _ajustes.copiar(saturacion: v)),
                ),
                _control(
                  'Nitidez',
                  _ajustes.nitidez,
                  0,
                  1,
                  (v) => _ajustar(bytes, _ajustes.copiar(nitidez: v)),
                ),
                if (_errorVista != null)
                  Text(
                    'No se pudo mostrar el ajuste.',
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                if (_guardando)
                  LinearProgressIndicator(
                    semanticsLabel: _requiereProcesamiento
                        ? 'Procesando fotografía'
                        : 'Guardando fotografía',
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _panel(String titulo, Widget contenido) => Column(
    children: [
      Text(titulo, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 4),
      Expanded(
        child: SizedBox.expand(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: contenido,
          ),
        ),
      ),
    ],
  );

  Widget _control(
    String nombre,
    double valor,
    double min,
    double max,
    ValueChanged<double> alCambiar,
  ) => Row(
    children: [
      SizedBox(
        width: math.min(110.0, MediaQuery.textScalerOf(context).scale(76)),
        child: Text(nombre),
      ),
      Expanded(
        child: Slider(
          semanticFormatterCallback: (v) => '$nombre ${(v * 100).round()} %',
          value: valor,
          min: min,
          max: max,
          divisions: ((max - min) * 100).round(),
          onChanged: _ocupado ? null : alCambiar,
        ),
      ),
      SizedBox(
        width: 48,
        child: Text('${(valor * 100).round()} %', textAlign: TextAlign.end),
      ),
    ],
  );

  void _desplazarCinta(PointerSignalEvent evento) {
    if (evento is! PointerScrollEvent ||
        evento.kind != PointerDeviceKind.mouse ||
        evento.scrollDelta.dx != 0 ||
        evento.scrollDelta.dy == 0 ||
        !_cinta.hasClients) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(evento, (resuelto) {
      if (_cinta.hasClients) {
        _cinta.position.pointerScroll(
          (resuelto as PointerScrollEvent).scrollDelta.dy,
        );
      }
    });
  }

  Widget _miniaturas() {
    final tema = Theme.of(context);
    return Listener(
      onPointerSignal: _desplazarCinta,
      child: ListView.builder(
        controller: _cinta,
        scrollDirection: Axis.horizontal,
        itemExtent: _anchoMiniatura,
        itemCount: _fotos.length,
        itemBuilder: (context, indice) {
          final foto = _fotos[indice];
          final seleccionada = indice == _indice;
          return Padding(
            padding: const EdgeInsets.all(5),
            child: Tooltip(
              message: foto.productor.nombreCompleto,
              child: Semantics(
                selected: seleccionada,
                button: true,
                child: InkWell(
                  onTap: _ocupado ? null : () => _irA(indice),
                  borderRadius: BorderRadius.circular(8),
                  child: Ink(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: seleccionada
                            ? tema.colorScheme.primary
                            : tema.colorScheme.outlineVariant,
                        width: seleccionada ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: ImagenAutenticada(
                        foto.miniatura,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
