import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/credencial_previa.dart';
import '../../models/diseno_credencial.dart';
import '../../repositories/diseno_credencial_repository.dart';
import '../padron_scope.dart';
import '../permisos_ui.dart';
import '../widgets/estados.dart';
import '../widgets/zona_soltar_archivos.dart';
import 'tarjeta_previa.dart';
import 'fuentes_bajo_demanda.dart';

class EditorCredencialPagina extends StatefulWidget {
  const EditorCredencialPagina({super.key, this.operadores = false});

  final bool operadores;

  @override
  State<EditorCredencialPagina> createState() => _EditorCredencialPaginaState();
}

class _EditorCredencialPaginaState extends State<EditorCredencialPagina> {
  EditorDisenoCredencial? _editor;
  DisenoCredencial? _diseno;
  CaraCredencial _cara = CaraCredencial.cara;
  String? _seleccion;
  String? _campoNuevo;
  Object? _error;
  bool _guardando = false;
  bool _guardandoPlantilla = false;
  bool _guardandoImagen = false;

  DisenoCredencialRepository get _repositorio {
    final padron = PadronScope.of(context);
    return widget.operadores
        ? DisenoCredencialRepository(
            padron.api,
            ruta: '/configuracion/credencial-operador',
          )
        : padron.disenoCredencial;
  }

  bool get _editable => context.puede(
    widget.operadores ? 'CREDENCIALES_OPERADORES_GESTIONAR' : 'CARNETS_DISENO',
  );

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final editor = await _repositorio.obtener();
      if (!mounted) return;
      setState(() {
        _editor = editor;
        _diseno = !widget.operadores && editor.diseno.elementos.isEmpty
            ? DisenoCredencial.predeterminado()
            : editor.diseno;
        _campoNuevo = editor.campos.firstOrNull?.campo;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _guardar() async {
    final diseno = _diseno;
    if (diseno == null || _guardando) return;
    setState(() => _guardando = true);
    try {
      final editor = await _repositorio.guardar(diseno);
      if (!mounted) return;
      setState(() {
        _editor = editor;
        _diseno = editor.diseno;
      });
      mostrarAviso(
        context,
        'Diseño guardado. Los próximos PDF usarán estos lugares.',
      );
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _restablecer() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.operadores
              ? 'Aplicar diseño vertical verde'
              : 'Restablecer diseño',
        ),
        content: Text(
          widget.operadores
              ? 'Se aplicará el diseño vertical verde de referencia en ambas caras. '
                    'Se reemplazarán los fondos cargados y la distribución de '
                    'campos. Los datos y fotografías del personal se conservarán.'
              : 'Se perderán los cambios de posición, tamaño y campos agregados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.operadores ? 'Aplicar diseño' : 'Restablecer'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      final editor = await _repositorio.restablecer();
      if (!mounted) return;
      setState(() {
        _editor = editor;
        _diseno = editor.diseno;
        _seleccion = null;
      });
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  void _cambiarOrientacion(OrientacionCredencial orientacion) {
    if (!widget.operadores || !_editable || _diseno == null) return;
    setState(() {
      _diseno = _diseno!.conOrientacion(orientacion);
    });
  }

  String? _plantillaUrl() {
    final url = _editor!.plantillaUrl(_cara);
    if (!widget.operadores || url == null) return url;
    final uri = Uri.parse(url);
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'orientacion': _diseno!.orientacion.name.toUpperCase(),
          },
        )
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final editable = _editable;
    final diseno = _diseno;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.operadores
                ? 'Diseño de credencial de operador'
                : 'Diseño del carnet',
          ),
        ),
        body: FalloCarga(error: _error!, alReintentar: _cargar),
      );
    }
    if (diseno == null || _editor == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.operadores
              ? 'Editor de credenciales de operadores'
              : 'Editor del carnet',
        ),
        actions: [
          if (!widget.operadores)
            TextButton.icon(
              onPressed: editable && !_guardando ? _restablecer : null,
              icon: const Icon(Icons.restore),
              label: const Text('Restablecer'),
            ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: !editable || _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar diseño'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, limites) {
          final anchoEditor = math.min(
            diseno.orientacion == OrientacionCredencial.vertical
                ? 420.0
                : 680.0,
            math.max(
              120.0,
              limites.maxWidth - (limites.maxWidth >= 1050 ? 390 : 32),
            ),
          );
          final lienzo = _LienzoEditable(
            diseno: diseno,
            cara: _cara,
            ancho: anchoEditor,
            seleccion: _seleccion,
            alSeleccionar: (id) => setState(() => _seleccion = id),
            alCambiar: _reemplazar,
            plantillaUrl: _plantillaUrl(),
            operadores: widget.operadores,
            editable: editable,
          );
          final panel = SizedBox(
            width: limites.maxWidth >= 1050 ? 350 : null,
            child: AbsorbPointer(
              absorbing: !editable,
              child: _PanelPropiedades(
                editor: _editor!,
                diseno: diseno,
                cara: _cara,
                seleccion: _seleccion,
                campoNuevo: _campoNuevo,
                alCambiarCampoNuevo: (valor) =>
                    setState(() => _campoNuevo = valor),
                alAgregar: _agregar,
                alSeleccionar: (id) => setState(() => _seleccion = id),
                alCambiar: _reemplazar,
                alEliminar: _eliminar,
                alSubirCapa: () => _moverCapa(1),
                alBajarCapa: () => _moverCapa(-1),
                operadores: widget.operadores,
              ),
            ),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.operadores) ...[
                  SegmentedButton<OrientacionCredencial>(
                    segments: const [
                      ButtonSegment(
                        value: OrientacionCredencial.horizontal,
                        icon: Icon(Icons.crop_landscape),
                        label: Text('Horizontal'),
                      ),
                      ButtonSegment(
                        value: OrientacionCredencial.vertical,
                        icon: Icon(Icons.crop_portrait),
                        label: Text('Vertical'),
                      ),
                    ],
                    selected: {diseno.orientacion},
                    onSelectionChanged: editable && !_guardando
                        ? (valor) => _cambiarOrientacion(valor.first)
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                SegmentedButton<CaraCredencial>(
                  segments: const [
                    ButtonSegment(
                      value: CaraCredencial.cara,
                      icon: Icon(Icons.badge_outlined),
                      label: Text('Cara'),
                    ),
                    ButtonSegment(
                      value: CaraCredencial.reverso,
                      icon: Icon(Icons.flip_to_back_outlined),
                      label: Text('Reverso'),
                    ),
                  ],
                  selected: {_cara},
                  onSelectionChanged: (valor) => setState(() {
                    _cara = valor.first;
                    _seleccion = null;
                  }),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.operadores)
                      OutlinedButton.icon(
                        onPressed: !editable || _guardando
                            ? null
                            : _restablecer,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Aplicar diseño vertical verde'),
                      ),
                    FilledButton.tonalIcon(
                      onPressed: !editable || _guardandoPlantilla
                          ? null
                          : _elegirPlantilla,
                      icon: const Icon(Icons.wallpaper_outlined),
                      label: Text(
                        'Cambiar plantilla de ${_cara == CaraCredencial.cara ? 'la cara' : 'el reverso'}',
                      ),
                    ),
                    if (_editor!.plantillaUrl(_cara) != null)
                      OutlinedButton.icon(
                        onPressed: !editable || _guardandoPlantilla
                            ? null
                            : _restablecerPlantilla,
                        icon: const Icon(Icons.restore_page_outlined),
                        label: Text(
                          widget.operadores
                              ? 'Usar fondo original'
                              : 'Usar plantilla original',
                        ),
                      ),
                    ZonaSoltarArchivos(
                      habilitada: editable && !_guardandoImagen,
                      extensionesPermitidas: extensionesImagen,
                      mensaje: 'Soltá aquí la imagen que querés insertar',
                      alSoltar: (archivos) async {
                        final archivo = await archivoSoltadoAPlatformFile(
                          archivos.single,
                        );
                        await _subirImagen(archivo);
                      },
                      child: OutlinedButton.icon(
                        onPressed: !editable || _guardandoImagen
                            ? null
                            : _elegirImagen,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Agregar imagen'),
                      ),
                    ),
                  ],
                ),
                const AyudaArrastrarArchivo(
                  texto: 'También podés arrastrar aquí la nueva plantilla.',
                ),
                const SizedBox(height: 12),
                Text(
                  widget.operadores
                      ? 'Cargá el diseño de la cara y del reverso de los '
                            'operadores. Arrastrá cada campo para moverlo y '
                            'usá el punto de la esquina superior derecha para '
                            'cambiar su ancho y alto. La reseña y la firma del '
                            'ejecutivo se comparten entre todas estas '
                            'credenciales. Usá imágenes de '
                            '${diseno.orientacion == OrientacionCredencial.vertical ? '851 × 1355' : '1355 × 851'} '
                            'px o de la misma proporción. La fotografía se '
                            'carga en la ficha de cada operador.'
                      : 'Arrastrá una caja para moverla. Usá el punto de la esquina '
                            'superior derecha para cambiar su ancho y alto. Si la '
                            'plantilla PNG tiene un hueco para la foto, dejá el objeto '
                            'Fotografía debajo de Plantilla. Para evitar deformaciones, '
                            'usá una imagen horizontal de 1355 × 851 px o de la misma '
                            'proporción. PNG conserva transparencias; JPG no.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (limites.maxWidth >= 1050)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Center(child: _zonaPlantilla(lienzo))),
                      const SizedBox(width: 24),
                      panel,
                    ],
                  )
                else ...[
                  Center(child: _zonaPlantilla(lienzo)),
                  const SizedBox(height: 24),
                  panel,
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _reemplazar(ElementoDisenoCredencial nuevo) {
    final diseno = _diseno!;
    setState(() {
      _diseno = diseno.conElementos([
        for (final e in diseno.elementos)
          if (e.id == nuevo.id) nuevo else e,
      ]);
    });
  }

  void _agregar() {
    final campo = _editor!.campos
        .where((c) => c.campo == _campoNuevo)
        .firstOrNull;
    if (campo == null) return;
    final id =
        '${campo.campo.toLowerCase()}-${DateTime.now().microsecondsSinceEpoch}';
    final tipo = campo.tipo;
    final nuevo = ElementoDisenoCredencial(
      id: id,
      cara: _cara,
      tipo: tipo,
      campo: campo.campo,
      etiqueta: campo.etiqueta,
      x: 20,
      y: 20,
      ancho: campo.campo == 'RESENA'
          ? math.min(200, _diseno!.ancho - 40)
          : tipo == TipoElementoCredencial.imagen
          ? 50
          : 90,
      alto: campo.campo == 'RESENA'
          ? 65
          : tipo == TipoElementoCredencial.imagen
          ? widget.operadores && campo.campo == 'FOTO'
                ? 50
                : 35
          : 12,
      tamanoFuente: campo.campo == 'RESENA'
          ? 7
          : tipo == TipoElementoCredencial.pieFirma
          ? 4.2
          : 8,
      negrita: campo.campo != 'RESENA' && tipo != TipoElementoCredencial.imagen,
      alineacion: tipo == TipoElementoCredencial.texto
          ? AlineacionCredencial.izquierda
          : AlineacionCredencial.centro,
      color: '#000000',
      texto: campo.campo == 'TEXTO_FIJO' ? 'NUEVO TEXTO' : '',
      circular: widget.operadores && campo.campo == 'FOTO',
    );
    setState(() {
      _diseno = _diseno!.conElementos([..._diseno!.elementos, nuevo]);
      _seleccion = id;
    });
  }

  void _eliminar() {
    final id = _seleccion;
    if (id == null) return;
    final seleccionado = _diseno!.elementos
        .where((e) => e.id == id)
        .firstOrNull;
    if (seleccionado?.tipo == TipoElementoCredencial.plantilla) return;
    setState(() {
      _diseno = _diseno!.conElementos(
        _diseno!.elementos.where((e) => e.id != id).toList(),
      );
      _seleccion = null;
    });
  }

  void _moverCapa(int direccion) {
    final id = _seleccion;
    final diseno = _diseno;
    if (id == null || diseno == null) return;
    final elementos = [...diseno.elementos];
    final indice = elementos.indexWhere((e) => e.id == id);
    if (indice < 0) return;
    final cara = elementos[indice].cara;
    final candidatos = <int>[
      for (var i = 0; i < elementos.length; i++)
        if (elementos[i].cara == cara) i,
    ];
    final posicion = candidatos.indexOf(indice);
    final nuevaPosicion = posicion + direccion;
    if (nuevaPosicion < 0 || nuevaPosicion >= candidatos.length) return;
    final otroIndice = candidatos[nuevaPosicion];
    final temporal = elementos[indice];
    elementos[indice] = elementos[otroIndice];
    elementos[otroIndice] = temporal;
    setState(() => _diseno = diseno.conElementos(elementos));
  }

  Future<void> _elegirPlantilla() async {
    try {
      final resultado = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final archivo = resultado?.files.firstOrNull;
      if (archivo != null) await _subirPlantilla(archivo);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _subirPlantilla(PlatformFile archivo) async {
    final bytes = archivo.bytes;
    if (bytes == null || bytes.isEmpty || _guardandoPlantilla) return;
    setState(() => _guardandoPlantilla = true);
    try {
      final editor = await _repositorio.subirPlantilla(
        _cara,
        bytes,
        archivo.name,
      );
      if (!mounted) return;
      setState(() => _editor = editor);
      mostrarAviso(
        context,
        'Plantilla actualizada. También se usará en los próximos PDF.',
      );
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardandoPlantilla = false);
    }
  }

  Future<void> _restablecerPlantilla() async {
    if (_guardandoPlantilla) return;
    setState(() => _guardandoPlantilla = true);
    try {
      final editor = await _repositorio.restablecerPlantilla(_cara);
      if (!mounted) return;
      setState(() => _editor = editor);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardandoPlantilla = false);
    }
  }

  Future<void> _elegirImagen() async {
    try {
      final resultado = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final archivo = resultado?.files.firstOrNull;
      if (archivo != null) await _subirImagen(archivo);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _subirImagen(PlatformFile archivo) async {
    final bytes = archivo.bytes;
    if (bytes == null || bytes.isEmpty || _guardandoImagen) return;
    setState(() => _guardandoImagen = true);
    try {
      final subida = await _repositorio.subirImagen(bytes, archivo.name);
      if (!mounted) return;
      final id = 'imagen-${DateTime.now().microsecondsSinceEpoch}';
      final etiqueta = archivo.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final nueva = ElementoDisenoCredencial(
        id: id,
        cara: _cara,
        tipo: TipoElementoCredencial.imagen,
        campo: 'IMAGEN_PERSONALIZADA',
        etiqueta: etiqueta.isEmpty ? 'Imagen' : etiqueta,
        x: 20,
        y: 20,
        ancho: 60,
        alto: 40,
        tamanoFuente: 5.5,
        negrita: false,
        alineacion: AlineacionCredencial.centro,
        color: '#000000',
        texto: '',
        recurso: subida.clave,
      );
      setState(() {
        _diseno = _diseno!.conElementos([..._diseno!.elementos, nueva]);
        _seleccion = id;
      });
      mostrarAviso(
        context,
        'Imagen agregada. Ajustá su posición y guardá el diseño.',
      );
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _guardandoImagen = false);
    }
  }

  Widget _zonaPlantilla(Widget lienzo) => ZonaSoltarArchivos(
    habilitada: _editable && !_guardandoPlantilla,
    extensionesPermitidas: extensionesImagen,
    mensaje: 'Soltá aquí la nueva plantilla',
    alSoltar: (archivos) async {
      final archivo = await archivoSoltadoAPlatformFile(archivos.single);
      await _subirPlantilla(archivo);
    },
    child: lienzo,
  );
}

class _LienzoEditable extends StatelessWidget {
  const _LienzoEditable({
    required this.diseno,
    required this.cara,
    required this.ancho,
    required this.seleccion,
    required this.alSeleccionar,
    required this.alCambiar,
    required this.plantillaUrl,
    required this.operadores,
    required this.editable,
  });

  final DisenoCredencial diseno;
  final CaraCredencial cara;
  final double ancho;
  final String? seleccion;
  final ValueChanged<String> alSeleccionar;
  final ValueChanged<ElementoDisenoCredencial> alCambiar;
  final String? plantillaUrl;
  final bool operadores;
  final bool editable;

  double get escala => ancho / diseno.ancho;

  @override
  Widget build(BuildContext context) {
    final elementos = diseno.elementos
        .where(
          (e) => e.cara == cara && e.tipo != TipoElementoCredencial.plantilla,
        )
        .toList();
    final seleccionado = elementos.where((e) => e.id == seleccion).firstOrNull;
    return SizedBox(
      width: ancho,
      height: diseno.alto * escala,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TarjetaPrevia(
            previa: operadores ? _muestraOperador : _muestra,
            reverso: cara == CaraCredencial.reverso,
            ancho: ancho,
            diseno: diseno,
            plantillaUrl: plantillaUrl,
            plantillaPorDefecto: !operadores,
            valores: operadores ? _valoresOperador : const {},
          ),
          if (editable)
            for (final e in elementos)
              _CajaMovible(
                key: ValueKey('caja-${e.id}'),
                elemento: e,
                diseno: diseno,
                escala: escala,
                elegido: seleccion == e.id,
                alSeleccionar: alSeleccionar,
                alCambiar: alCambiar,
              ),
          if (editable && seleccionado != null)
            _ControlRedimension(
              key: ValueKey('redimension-${seleccionado.id}'),
              elemento: seleccionado,
              diseno: diseno,
              escala: escala,
              alCambiar: alCambiar,
            ),
        ],
      ),
    );
  }
}

class _CajaMovible extends StatefulWidget {
  const _CajaMovible({
    super.key,
    required this.elemento,
    required this.diseno,
    required this.escala,
    required this.elegido,
    required this.alSeleccionar,
    required this.alCambiar,
  });

  final ElementoDisenoCredencial elemento;
  final DisenoCredencial diseno;
  final double escala;
  final bool elegido;
  final ValueChanged<String> alSeleccionar;
  final ValueChanged<ElementoDisenoCredencial> alCambiar;

  @override
  State<_CajaMovible> createState() => _CajaMovibleState();
}

class _CajaMovibleState extends State<_CajaMovible> {
  ElementoDisenoCredencial? _inicio;
  Offset _recorrido = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final e = widget.elemento;
    return Positioned(
      left: e.x * widget.escala,
      bottom: e.y * widget.escala,
      width: e.ancho * widget.escala,
      height: math.max(e.alto, e.tamanoFuente) * widget.escala,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.alSeleccionar(e.id),
        onPanStart: (_) {
          _inicio = e;
          _recorrido = Offset.zero;
          widget.alSeleccionar(e.id);
        },
        onPanUpdate: (detalle) {
          final base = _inicio ?? e;
          _recorrido += detalle.delta;
          final nx = (base.x + _recorrido.dx / widget.escala).clamp(
            0.0,
            widget.diseno.ancho - base.ancho,
          );
          final ny = (base.y - _recorrido.dy / widget.escala).clamp(
            0.0,
            widget.diseno.alto - base.alto,
          );
          widget.alCambiar(base.copiar(x: nx, y: ny));
        },
        onPanEnd: (_) => _inicio = null,
        onPanCancel: () => _inicio = null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.elegido
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .08)
                : Colors.transparent,
            border: Border.all(
              color: widget.elegido
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlRedimension extends StatefulWidget {
  const _ControlRedimension({
    super.key,
    required this.elemento,
    required this.diseno,
    required this.escala,
    required this.alCambiar,
  });

  static const double areaAgarre = 40;
  static const double diametroVisible = 18;

  final ElementoDisenoCredencial elemento;
  final DisenoCredencial diseno;
  final double escala;
  final ValueChanged<ElementoDisenoCredencial> alCambiar;

  @override
  State<_ControlRedimension> createState() => _ControlRedimensionState();
}

class _ControlRedimensionState extends State<_ControlRedimension> {
  ElementoDisenoCredencial? _inicio;
  Offset _recorrido = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final e = widget.elemento;
    final altoVisible = math.max(e.alto, e.tamanoFuente);
    const mitad = _ControlRedimension.areaAgarre / 2;
    return Positioned(
      left: (e.x + e.ancho) * widget.escala - mitad,
      bottom: (e.y + altoVisible) * widget.escala - mitad,
      width: _ControlRedimension.areaAgarre,
      height: _ControlRedimension.areaAgarre,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpRightDownLeft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            _inicio = e;
            _recorrido = Offset.zero;
          },
          onPanUpdate: (detalle) {
            final base = _inicio ?? e;
            _recorrido += detalle.delta;
            final anchoNuevo = (base.ancho + _recorrido.dx / widget.escala)
                .clamp(2.0, widget.diseno.ancho - base.x);
            final altoNuevo = (base.alto - _recorrido.dy / widget.escala).clamp(
              2.0,
              widget.diseno.alto - base.y,
            );
            widget.alCambiar(base.copiar(ancho: anchoNuevo, alto: altoNuevo));
          },
          onPanEnd: (_) => _inicio = null,
          onPanCancel: () => _inicio = null,
          child: Center(
            child: Container(
              width: _ControlRedimension.diametroVisible,
              height: _ControlRedimension.diametroVisible,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x55000000), blurRadius: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelPropiedades extends StatelessWidget {
  const _PanelPropiedades({
    required this.editor,
    required this.diseno,
    required this.cara,
    required this.seleccion,
    required this.campoNuevo,
    required this.alCambiarCampoNuevo,
    required this.alAgregar,
    required this.alSeleccionar,
    required this.alCambiar,
    required this.alEliminar,
    required this.alSubirCapa,
    required this.alBajarCapa,
    this.operadores = false,
  });

  final EditorDisenoCredencial editor;
  final DisenoCredencial diseno;
  final CaraCredencial cara;
  final String? seleccion;
  final String? campoNuevo;
  final ValueChanged<String?> alCambiarCampoNuevo;
  final VoidCallback alAgregar;
  final ValueChanged<String> alSeleccionar;
  final ValueChanged<ElementoDisenoCredencial> alCambiar;
  final VoidCallback alEliminar;
  final VoidCallback alSubirCapa;
  final VoidCallback alBajarCapa;
  final bool operadores;

  @override
  Widget build(BuildContext context) {
    final visibles = diseno.elementos.where((e) => e.cara == cara).toList();
    final actual = visibles.where((e) => e.id == seleccion).firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Campos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: campoNuevo,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Nuevo campo',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final campo in editor.campos)
                        DropdownMenuItem(
                          value: campo.campo,
                          child: Text(campo.etiqueta),
                        ),
                    ],
                    onChanged: alCambiarCampoNuevo,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Agregar campo',
                  onPressed: alAgregar,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in visibles)
                  ChoiceChip(
                    label: Text(e.etiqueta),
                    selected: e.id == seleccion,
                    onSelected: (_) => alSeleccionar(e.id),
                  ),
              ],
            ),
            const Divider(height: 32),
            if (actual == null)
              const Text('Seleccioná un campo en la tarjeta o en la lista.')
            else ...[
              Text(
                actual.etiqueta,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (actual.tipo != TipoElementoCredencial.plantilla) ...[
                Row(
                  children: [
                    Expanded(
                      child: _numero(
                        'X',
                        actual.x,
                        (v) => alCambiar(
                          actual.copiar(
                            x: v.clamp(0, diseno.ancho - actual.ancho),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _numero(
                        'Y',
                        actual.y,
                        (v) => alCambiar(
                          actual.copiar(
                            y: v.clamp(0, diseno.alto - actual.alto),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (operadores && actual.campo == 'FOTO')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fotografía circular'),
                    value: actual.circular,
                    onChanged: (valor) =>
                        alCambiar(actual.copiar(circular: valor)),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _numero(
                        'Ancho',
                        actual.ancho,
                        (v) => alCambiar(
                          actual.copiar(
                            ancho: v.clamp(2, diseno.ancho - actual.x),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _numero(
                        'Alto',
                        actual.alto,
                        (v) => alCambiar(
                          actual.copiar(
                            alto: v.clamp(2, diseno.alto - actual.y),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (actual.tipo != TipoElementoCredencial.imagen) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<FuenteCredencial>(
                    key: ValueKey('fuente-${actual.id}'),
                    initialValue: actual.fuente,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de letra',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final fuente in FuenteCredencial.values)
                        DropdownMenuItem(
                          value: fuente,
                          child: FuentesBajoDemanda(
                            fuentes: {fuente},
                            child: Text(
                              '${fuente.etiqueta} — ${fuente.descripcion}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: fuente.familiaFlutter,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                    onChanged: (fuente) {
                      if (fuente != null) {
                        alCambiar(actual.copiar(fuente: fuente));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tamaño de letra: ${actual.tamanoFuente.toStringAsFixed(1)} pt',
                  ),
                  Slider(
                    min: 3,
                    max: 20,
                    divisions: 68,
                    value: actual.tamanoFuente.clamp(3, 20),
                    onChanged: (v) => alCambiar(actual.copiar(tamanoFuente: v)),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Negrita'),
                    value: actual.negrita,
                    onChanged: (v) =>
                        alCambiar(actual.copiar(negrita: v ?? false)),
                  ),
                  SegmentedButton<AlineacionCredencial>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: AlineacionCredencial.izquierda,
                        icon: Icon(Icons.format_align_left),
                      ),
                      ButtonSegment(
                        value: AlineacionCredencial.centro,
                        icon: Icon(Icons.format_align_center),
                      ),
                      ButtonSegment(
                        value: AlineacionCredencial.derecha,
                        icon: Icon(Icons.format_align_right),
                      ),
                    ],
                    selected: {actual.alineacion},
                    onSelectionChanged: (v) =>
                        alCambiar(actual.copiar(alineacion: v.first)),
                  ),
                ],
                if (actual.campo == 'TEXTO_FIJO') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey('texto-${actual.id}'),
                    initialValue: actual.texto,
                    decoration: const InputDecoration(
                      labelText: 'Texto',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => alCambiar(actual.copiar(texto: v)),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              Text(
                'Nivel del objeto',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: visibles.first.id == actual.id
                          ? null
                          : alBajarCapa,
                      icon: const Icon(Icons.vertical_align_bottom),
                      label: const Text('Bajar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: visibles.last.id == actual.id
                          ? null
                          : alSubirCapa,
                      icon: const Icon(Icons.vertical_align_top),
                      label: const Text('Subir'),
                    ),
                  ),
                ],
              ),
              Text(
                'Los objetos de arriba se imprimen por encima de los de abajo.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (actual.tipo != TipoElementoCredencial.plantilla) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: alEliminar,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Quitar este objeto'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _numero(
    String etiqueta,
    double valor,
    ValueChanged<double> alCambiar,
  ) {
    return TextFormField(
      key: ValueKey(etiqueta + valor.toStringAsFixed(2)),
      initialValue: valor.toStringAsFixed(2),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: etiqueta,
        suffixText: 'pt',
        border: const OutlineInputBorder(),
      ),
      onFieldSubmitted: (texto) {
        final numero = double.tryParse(texto.replaceAll(',', '.'));
        if (numero != null) alCambiar(numero);
      },
    );
  }
}

const _muestra = CredencialPrevia(
  productorId: 0,
  nombreCompleto: 'MARÍA QUISPE MAMANI',
  federacion: 'FEDERACIÓN CARRASCO',
  central: 'IVIRGARZAMA',
  sindicato: 'ALTO SAN SALVADOR',
  nombres: 'MARÍA',
  apellidos: 'QUISPE MAMANI',
  ci: '4487439',
  lotes: '12',
  codigoPadron: '2IVI1',
  codigoQr: 'MUESTRA',
  ejecutivoFederacion: FirmantePrevio(
    nombre: 'ANA CHOQUE MAMANI',
    cargo: 'EJECUTIVO',
    organizacion: 'FEDERACIÓN CARRASCO',
    tieneFirma: true,
  ),
  secretarioGeneralCentral: FirmantePrevio(
    nombre: 'BRUNO LIMACHI QUISPE',
    cargo: 'SECRETARIO GENERAL',
    organizacion: 'IVIRGARZAMA',
    tieneFirma: true,
  ),
  secretarioGeneralSindicato: FirmantePrevio(
    nombre: 'CARLA MAMANI COLQUE',
    cargo: 'SECRETARIO GENERAL',
    organizacion: 'ALTO SAN SALVADOR',
    tieneFirma: true,
  ),
  faltantes: [],
  completa: true,
);

const _muestraOperador = CredencialPrevia(
  productorId: 0,
  nombreCompleto: 'CARLOS PÉREZ',
  federacion: 'FEDERACIÓN CARRASCO',
  central: '',
  sindicato: '',
  nombres: 'CARLOS',
  apellidos: 'PÉREZ',
  ci: '1234567',
  lotes: '',
  codigoQr: '',
  ejecutivoFederacion: FirmantePrevio(
    nombre: 'EJECUTIVO DE LA FEDERACIÓN',
    cargo: 'EJECUTIVO',
    organizacion: 'FEDERACIÓN CARRASCO',
    tieneFirma: true,
  ),
  faltantes: [],
  completa: true,
);

const _valoresOperador = {
  'CARGO': 'OPERADOR DEL SOFTWARE',
  'TELEFONO': '70012345',
  'RESENA':
      'La Federación Carrasco autoriza al portador de esta credencial '
      'a realizar las tareas de operación del software asignadas. '
      'Esta autorización es personal y debe presentarse cuando sea requerida.',
};
