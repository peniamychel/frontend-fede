import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/credencial_previa.dart';
import '../../models/diseno_credencial.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import '../widgets/zona_soltar_archivos.dart';
import 'tarjeta_previa.dart';
import 'fuentes_bajo_demanda.dart';

class EditorCredencialPagina extends StatefulWidget {
  const EditorCredencialPagina({super.key});

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

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final editor = await PadronScope.of(context).disenoCredencial.obtener();
      if (!mounted) return;
      setState(() {
        _editor = editor;
        _diseno = editor.diseno.elementos.isEmpty
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
      final editor = await PadronScope.of(
        context,
      ).disenoCredencial.guardar(diseno);
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
        title: const Text('Restablecer diseño'),
        content: const Text(
          'Se perderán los cambios de posición, tamaño y campos agregados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      final editor = await PadronScope.of(
        context,
      ).disenoCredencial.restablecer();
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

  @override
  Widget build(BuildContext context) {
    final diseno = _diseno;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diseño del carnet')),
        body: FalloCarga(error: _error!, alReintentar: _cargar),
      );
    }
    if (diseno == null || _editor == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor del carnet'),
        actions: [
          TextButton.icon(
            onPressed: _restablecer,
            icon: const Icon(Icons.restore),
            label: const Text('Restablecer'),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
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
            680.0,
            math.max(
              320.0,
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
            plantillaUrl: _editor!.plantillaUrl(_cara),
          );
          final panel = SizedBox(
            width: limites.maxWidth >= 1050 ? 350 : null,
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
            ),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    FilledButton.tonalIcon(
                      onPressed: _guardandoPlantilla ? null : _elegirPlantilla,
                      icon: const Icon(Icons.wallpaper_outlined),
                      label: Text(
                        'Cambiar plantilla de ${_cara == CaraCredencial.cara ? 'la cara' : 'el reverso'}',
                      ),
                    ),
                    if (_editor!.plantillaUrl(_cara) != null)
                      OutlinedButton.icon(
                        onPressed: _guardandoPlantilla
                            ? null
                            : _restablecerPlantilla,
                        icon: const Icon(Icons.restore_page_outlined),
                        label: const Text('Usar plantilla original'),
                      ),
                    ZonaSoltarArchivos(
                      habilitada: !_guardandoImagen,
                      extensionesPermitidas: extensionesImagen,
                      mensaje: 'Soltá aquí la imagen que querés insertar',
                      alSoltar: (archivos) async {
                        final archivo = await archivoSoltadoAPlatformFile(
                          archivos.single,
                        );
                        await _subirImagen(archivo);
                      },
                      child: OutlinedButton.icon(
                        onPressed: _guardandoImagen ? null : _elegirImagen,
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
                  'Arrastrá una caja para moverla. Usá el punto de la esquina '
                  'superior derecha para cambiar su ancho y alto. Si la '
                  'plantilla PNG tiene un hueco para la foto, dejá el objeto '
                  'Fotografía debajo de Plantilla.',
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
      ancho: tipo == TipoElementoCredencial.imagen ? 50 : 90,
      alto: tipo == TipoElementoCredencial.imagen ? 35 : 12,
      tamanoFuente: tipo == TipoElementoCredencial.pieFirma ? 4.2 : 8,
      negrita: tipo != TipoElementoCredencial.imagen,
      alineacion: tipo == TipoElementoCredencial.texto
          ? AlineacionCredencial.izquierda
          : AlineacionCredencial.centro,
      color: '#000000',
      texto: campo.campo == 'TEXTO_FIJO' ? 'NUEVO TEXTO' : '',
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
      final editor = await PadronScope.of(
        context,
      ).disenoCredencial.subirPlantilla(_cara, bytes, archivo.name);
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
      final editor = await PadronScope.of(
        context,
      ).disenoCredencial.restablecerPlantilla(_cara);
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
      final subida = await PadronScope.of(
        context,
      ).disenoCredencial.subirImagen(bytes, archivo.name);
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
    habilitada: !_guardandoPlantilla,
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
  });

  final DisenoCredencial diseno;
  final CaraCredencial cara;
  final double ancho;
  final String? seleccion;
  final ValueChanged<String> alSeleccionar;
  final ValueChanged<ElementoDisenoCredencial> alCambiar;
  final String? plantillaUrl;

  double get escala => ancho / TarjetaPrevia.anchoPt;

  @override
  Widget build(BuildContext context) {
    final elementos = diseno.elementos.where(
      (e) => e.cara == cara && e.tipo != TipoElementoCredencial.plantilla,
    );
    return SizedBox(
      width: ancho,
      height: TarjetaPrevia.altoPt * escala,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TarjetaPrevia(
            previa: _muestra,
            reverso: cara == CaraCredencial.reverso,
            ancho: ancho,
            diseno: diseno,
            plantillaUrl: plantillaUrl,
          ),
          for (final e in elementos) _caja(context, e),
        ],
      ),
    );
  }

  Widget _caja(BuildContext context, ElementoDisenoCredencial e) {
    final elegido = seleccion == e.id;
    return Positioned(
      left: e.x * escala,
      bottom: e.y * escala,
      width: e.ancho * escala,
      height: math.max(e.alto, e.tamanoFuente) * escala,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => alSeleccionar(e.id),
        onPanStart: (_) => alSeleccionar(e.id),
        onPanUpdate: (detalle) {
          final nx = (e.x + detalle.delta.dx / escala).clamp(
            0.0,
            diseno.ancho - e.ancho,
          );
          final ny = (e.y - detalle.delta.dy / escala).clamp(
            0.0,
            diseno.alto - e.alto,
          );
          alCambiar(e.copiar(x: nx, y: ny));
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: elegido
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .08)
                : Colors.transparent,
            border: Border.all(
              color: elegido
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: elegido
              ? Align(
                  alignment: Alignment.topRight,
                  child: Transform.translate(
                    offset: const Offset(7, -7),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (detalle) {
                        final anchoNuevo = (e.ancho + detalle.delta.dx / escala)
                            .clamp(2.0, diseno.ancho - e.x);
                        final altoNuevo = (e.alto - detalle.delta.dy / escala)
                            .clamp(2.0, diseno.alto - e.y);
                        alCambiar(e.copiar(ancho: anchoNuevo, alto: altoNuevo));
                      },
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
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
  lotes: '12-A',
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
