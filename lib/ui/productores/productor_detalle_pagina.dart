import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/guardar_archivo.dart';
import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../permisos_ui.dart';
import '../credenciales/credencial_previa_pagina.dart';
import '../lotes/lote_pagina.dart';
import '../widgets/estados.dart';
import 'asignar_parcela.dart';
import '../widgets/marca_estado.dart';
import 'imagenes_productor.dart';
import 'ficha_resumen_productor.dart';
import 'productor_formulario.dart';

/// Cierra una ficha integrada respetando sus avisos de salida.
class ProductorDetalleControlador {
  _ProductorDetallePaginaState? _estado;

  Future<bool> cerrar() async => await _estado?._salir() ?? true;
}

/// Ficha completa de un productor: sus datos, sus lotes y sus imágenes.
class ProductorDetallePagina extends StatefulWidget {
  const ProductorDetallePagina({
    super.key,
    required this.productorId,
    this.controlador,
    this.alCerrar,
    this.alActualizar,
  });

  final int productorId;
  final ProductorDetalleControlador? controlador;
  final Future<void> Function(bool huboCambios)? alCerrar;
  final ValueChanged<Productor>? alActualizar;

  @override
  State<ProductorDetallePagina> createState() => _ProductorDetallePaginaState();
}

class _ProductorDetallePaginaState extends State<ProductorDetallePagina> {
  late Future<ProductorDetalle> _futuro;
  int _versionDetalle = 0;

  /// Va aparte de la ficha porque es otra consulta: el historial de cargos
  /// incluye los de sindicatos anteriores y no cuelga del detalle.
  late Future<List<Cargo>> _cargos;

  /// Si se tocó algo, la lista de la que venimos tiene que recargarse.
  bool _huboCambios = false;
  bool _editoProductorImpreso = false;
  bool _reimpresionSolicitada = false;
  bool _saliendo = false;

  /// Resultado de la revisión automática realizada durante esta apertura.
  RevisionSieProductor? _revisionSie;

  bool _verificandoSie = false;
  bool _agregandoReimpresion = false;
  bool _descargandoFicha = false;
  final _claveFotoFicha = GlobalKey();
  final _claveAntecedentes = GlobalKey();

  Future<void> _descargarFicha(ProductorDetalle detalle) async {
    if (_descargandoFicha) return;
    final repositorio = PadronScope.of(context).productores;
    setState(() => _descargandoFicha = true);
    try {
      Uint8List? foto;
      if (detalle.imagen(TipoImagen.original) != null) {
        final descarga = await repositorio.descargarFotografia(
          detalle.productor.id,
        );
        foto = Uint8List.fromList(descarga.bytes);
      }
      final bytes = await generarFichaResumenProductor(
        detalle,
        fotografia: foto,
      );
      if (!mounted) return;
      await guardarArchivo(
        bytes,
        'ficha-productor-${detalle.productor.id}.png',
        'image/png',
      );
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _descargandoFicha = false);
    }
  }

  /// Nombre ya cargado, solo para nombrarlo en el aviso de la descarga. Se
  /// anota al dibujar la ficha y no dispara redibujado: no se muestra en
  /// ningún lado, lo lee el botón de la credencial.
  String? _nombre;

  @override
  void initState() {
    super.initState();
    widget.controlador?._estado = this;
    _recargar();
  }

  @override
  void didUpdateWidget(covariant ProductorDetallePagina oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controlador, widget.controlador)) {
      if (identical(oldWidget.controlador?._estado, this)) {
        oldWidget.controlador?._estado = null;
      }
      widget.controlador?._estado = this;
    }
  }

  @override
  void dispose() {
    if (identical(widget.controlador?._estado, this)) {
      widget.controlador?._estado = null;
    }
    super.dispose();
  }

  Future<void> _terminar(bool huboCambios) async {
    if (widget.alCerrar case final cerrar?) {
      await cerrar(huboCambios);
    } else {
      Navigator.of(context).pop(huboCambios);
    }
  }

  /// Va a la vista previa, no al PDF.
  ///
  /// La credencial se plastifica y se reparte: primero se mira cómo va a
  /// quedar y qué le falta. Desde ahí se genera, si está completa.
  Future<void> _verCredencial() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CredencialPreviaPagina(
          productorId: widget.productorId,
          nombre: _nombre ?? 'el productor',
        ),
      ),
    );
    // Al volver puede haber cargado la foto o la cédula que faltaba.
    if (mounted) {
      // La vista previa también puede registrar una impresión manual. La
      // lista de origen debe releer el icono verde al cerrar esta ficha.
      _huboCambios = true;
      _recargar();
    }
  }

  Future<void> _abrirLote(Lote lote) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LotePagina(loteId: lote.id)),
    );
    if (cambio == true && mounted) {
      _huboCambios = true;
      _recargar();
    }
  }

  /// Da de baja al productor, o lo reincorpora.
  ///
  /// Es la única salida: el productor no se borra. Alguien que deja el
  /// sindicato puede volver años después —compra otra parcela y se reafilia— y
  /// si su ficha hubiera desaparecido habría que cargarlo de cero, perdiendo su
  /// código, su historial de tenencias y los cargos que ocupó.
  Future<void> _cambiarEstado(Productor p, bool tieneParcela) async {
    final nombre = p.nombreCompleto.isEmpty ? p.nombres : p.nombreCompleto;
    final cambio = await cambiarEstadoConAviso(
      context,
      nombre: nombre,
      habilitado: p.habilitado,
      titulo: '¿Dar de baja a $nombre?',
      mensaje:
          'Queda dado de baja, no se borra. Su ficha, su código y su '
          'historial siguen ahí, y si vuelve al padrón se lo reincorpora desde '
          'acá sin registrarlo de nuevo.'
          '${tieneParcela ? '\n\nOjo: todavía tiene una parcela a su nombre. '
                    'Conviene quitársela antes, o la tierra queda a nombre de alguien '
                    'que ya no está.' : ''}',
      accion: (estado) =>
          PadronScope.of(context).productores.cambiarEstado(p.id, estado),
    );
    if (cambio && mounted) {
      _huboCambios = true;
      _recargar();
    }
  }

  /// La ficha se conserva íntegra en la papelera. La parcela vigente debe
  /// traspasarse o quitarse antes de retirar al productor del padrón.
  Future<void> _eliminar(ProductorDetalle detalle) async {
    final productor = detalle.productor;
    final nombre = productor.nombreCompleto.isEmpty
        ? productor.nombres
        : productor.nombreCompleto;

    if (detalle.lotes.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.landscape_outlined),
          title: const Text('No se puede eliminar'),
          content: Text(
            '$nombre todavía tiene ${detalle.lotes.length == 1 ? 'una parcela' : '${detalle.lotes.length} parcelas'} '
            'a su nombre. Primero traspásala o quítala desde la sección '
            'Parcela; así no queda tierra sin responsable.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text('¿Mover a $nombre a la papelera?'),
        content: const Text(
          'Dejará de aparecer en el padrón y su carnet no podrá emitirse. '
          'Su ficha, fotografías e historial se conservarán y podrá restaurarse '
          'si su cédula no se registra en otro productor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Mover a la papelera'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await PadronScope.of(context).productores.eliminar(productor.id);
      if (!mounted) return;
      _huboCambios = true;
      await _terminar(true);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  /// Los vetos de esta persona. Va aparte de la ficha por lo mismo que los
  /// cargos: es otra consulta, y un fallo acá no puede tapar el resto.
  late Future<List<Veto>> _vetos;

  void _recargar() {
    final padron = PadronScope.of(context);
    setState(() {
      _revisionSie = null;
      _futuro = _sincronizarDetalle(_cargarDetalleConRevision(padron));
      _cargos = context.accesoCentral || context.soloFotosObservaciones
          ? Future.value(<Cargo>[])
          : padron.productores.cargos(widget.productorId);
      _vetos = context.accesoCentral || context.soloFotosObservaciones
          ? Future.value(<Veto>[])
          : padron.vetos.historialDe(widget.productorId);
    });
  }

  Future<ProductorDetalle> _sincronizarDetalle(
    Future<ProductorDetalle> futuro,
  ) async {
    final version = ++_versionDetalle;
    final detalle = await futuro;
    if (mounted && version == _versionDetalle) {
      widget.alActualizar?.call(detalle.productor);
    }
    return detalle;
  }

  Future<ProductorDetalle> _cargarDetalleConRevision(Padron padron) async {
    var detalle = await padron.productores.obtener(widget.productorId);
    if (!mounted) return detalle;
    final puedeRevisarSie = context.puede('SIE_REVISAR');
    if (!puedeRevisarSie) return detalle;
    if (!detalle.productor.revisionSiePendiente) return detalle;

    var resultado = await padron.productores.revisarImportadoConSie(
      widget.productorId,
    );
    resultado = await _confirmarDiferenciasSie(padron, resultado);
    _revisionSie = resultado;
    if (resultado.datosModificados) _huboCambios = true;

    // Al completar se relee la ficha para mostrar de inmediato la corrección.
    // Una caída temporal no apaga la marca: se intentará en otra apertura.
    if (resultado.completada ||
        resultado.estado == EstadoRevisionSie.requiereConfirmacion) {
      // La revisión también modifica el estado aunque el nombre coincida.
      // La lista debe releerlo al volver para retirar el aspecto pendiente.
      _huboCambios = true;
      detalle = await padron.productores.obtener(widget.productorId);
    }
    return detalle;
  }

  Future<RevisionSieProductor> _confirmarDiferenciasSie(
    Padron padron,
    RevisionSieProductor propuesta,
  ) async {
    if (!mounted ||
        propuesta.estado != EstadoRevisionSie.requiereConfirmacion) {
      return propuesta;
    }
    String nombre(Map<String, dynamic>? datos) => [
      datos?['nombres'],
      datos?['apellidos'],
    ].where((v) => v != null && v.toString().trim().isNotEmpty).join(' ');
    final aceptar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('El nombre no coincide con SIE'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para la cédula ${propuesta.actuales?['ci'] ?? ''}, '
                'SIE devuelve un nombre diferente al registrado.',
              ),
              const SizedBox(height: 16),
              const Text('Datos actuales:'),
              Text(nombre(propuesta.actuales)),
              const SizedBox(height: 12),
              const Text('Datos encontrados en SIE:'),
              Text(nombre(propuesta.propuestos)),
              const SizedBox(height: 16),
              const Text(
                '¿Querés reemplazar los nombres y apellidos por los de SIE?',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, conservar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, reemplazar'),
          ),
        ],
      ),
    );
    // Volver atrás o cerrar la ficha no equivale a aprobar ni a rechazar.
    if (aceptar == null || !mounted) return propuesta;
    return padron.productores.confirmarRevisionSie(
      widget.productorId,
      propuesta,
      aceptar: aceptar,
    );
  }

  Future<void> _verificarConSie(Productor productor) async {
    if (_verificandoSie) return;

    final ci = productor.ci?.trim();
    if (ci == null || ci.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.badge_outlined),
          title: const Text('Falta la cédula'),
          content: const Text(
            'Este productor no tiene una cédula registrada. Agrégala desde '
            'Editar antes de verificar sus datos con SIE.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.fact_check_outlined),
        title: const Text('¿Verificar con SIE?'),
        content: Text(
          'Se consultará la cédula $ci. Si SIE devuelve nombres o apellidos '
          'diferentes, podrás revisarlos y decidir si querés reemplazarlos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Verificar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _verificandoSie = true);
    try {
      final padron = PadronScope.of(context);
      var resultado = await padron.productores.verificarManualmenteConSie(
        productor.id,
      );
      resultado = await _confirmarDiferenciasSie(padron, resultado);
      if (!mounted) return;
      if (resultado.datosModificados) _huboCambios = true;
      setState(() {
        _revisionSie = resultado;
        _verificandoSie = false;
        if (resultado.completada) {
          _huboCambios = true;
          _futuro = _sincronizarDetalle(
            padron.productores.obtener(widget.productorId),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _verificandoSie = false);
      mostrarError(context, e);
    }
  }

  Future<void> _editarObservacion(Productor productor) async {
    var texto = productor.observacion ?? '';
    final formulario = GlobalKey<FormState>();
    final accion = await showDialog<_AccionObservacion>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        icon: Icon(
          Icons.report_problem_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          productor.observado ? 'Editar observación' : 'Marcar como observado',
        ),
        content: Form(
          key: formulario,
          child: TextFormField(
            initialValue: texto,
            onChanged: (valor) => texto = valor,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Motivo de la observación',
              hintText: 'Escribí qué se debe revisar o corregir',
              alignLabelWithHint: true,
            ),
            validator: (valor) => valor == null || valor.trim().isEmpty
                ? 'Escribí el motivo de la observación'
                : null,
          ),
        ),
        actions: [
          if (productor.observado && context.puede('PRODUCTORES_EDITAR'))
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_AccionObservacion.quitar),
              child: const Text('Quitar observación'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formulario.currentState?.validate() != true) return;
              Navigator.of(context).pop(_AccionObservacion.guardar);
            },
            child: const Text('Guardar observación'),
          ),
        ],
      ),
    );
    texto = texto.trim();
    if (accion == null || !mounted) return;

    try {
      final repositorio = PadronScope.of(context).productores;
      if (accion == _AccionObservacion.quitar) {
        await repositorio.quitarObservacion(productor.id);
      } else {
        await repositorio.observar(productor.id, texto);
      }
      if (!mounted) return;
      _huboCambios = true;
      mostrarExito(
        context,
        accion == _AccionObservacion.quitar
            ? 'Observación quitada'
            : 'Productor marcado como observado',
      );
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _aceptarSugerenciaSie(Productor productor) async {
    if (!productor.tieneSugerenciaSie) return;
    final nombreSugerido = [
      productor.sieNombresSugeridos,
      productor.sieApellidosSugeridos,
    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.fact_check_outlined),
        title: const Text('¿Aceptar la sugerencia guardada?'),
        content: Text(
          'Se reemplazarán los nombres y apellidos actuales por '
          '«$nombreSugerido». No se volverá a consultar el servicio SIE.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aceptar corrección'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    final propuesta = RevisionSieProductor(
      estado: EstadoRevisionSie.requiereConfirmacion,
      completada: false,
      datosModificados: false,
      mensaje: productor.revisionSieMensaje ?? '',
      actuales: {
        'ci': productor.ci,
        'nombres': productor.nombresCorregidos ?? productor.nombres,
        'apellidos': productor.apellidosCorregidos ?? productor.apellidos,
      },
      propuestos: {
        'ci': productor.ci,
        'nombres': productor.sieNombresSugeridos,
        'apellidos': productor.sieApellidosSugeridos,
      },
    );
    try {
      await PadronScope.of(context).productores.confirmarRevisionSie(
        productor.id,
        propuesta,
        aceptar: true,
      );
      if (!mounted) return;
      _huboCambios = true;
      mostrarExito(context, 'Corrección SIE aceptada');
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _aprobarDatosActualesSie(Productor productor) async {
    final puedeAprobar =
        productor.revisionSieEstado ==
            EstadoRevisionSiePersistida.noEncontrado ||
        productor.revisionSieEstado ==
            EstadoRevisionSiePersistida.diferenciaPendiente;
    if (_verificandoSie || !puedeAprobar) {
      return;
    }
    final hayDiferencia =
        productor.revisionSieEstado ==
        EstadoRevisionSiePersistida.diferenciaPendiente;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.how_to_reg_outlined),
        title: const Text('¿Aprobar los datos actuales?'),
        content: Text(
          'Se conservarán los nombres, apellidos y cédula actuales. ${hayDiferencia ? 'No se aplicará la sugerencia de SIE. ' : ''}'
          'La advertencia de SIE quedará aprobada y dejará de bloquear la '
          'impresión. Si existe una observación manual independiente, esa '
          'observación seguirá vigente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Aprobar datos actuales'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _verificandoSie = true);
    try {
      await PadronScope.of(
        context,
      ).productores.aprobarDatosActualesSie(productor.id);
      if (!mounted) return;
      _huboCambios = true;
      setState(() => _verificandoSie = false);
      mostrarExito(context, 'Datos del productor aprobados');
      _recargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _verificandoSie = false);
      mostrarError(context, e);
    }
  }

  /// El aviso de que está observado, arriba de todo.
  ///
  /// Va antes que cualquier otro dato porque es lo primero que hay que saber de
  /// esa persona: su credencial no se emite.
  ///
  /// Solo informa. Vetar y levantar no se deciden acá: se deciden en asamblea,
  /// y se cargan desde la reunión que lo decidió. Poner el botón en la ficha
  /// invitaba a sancionar mirando a una persona, que es exactamente al revés de
  /// cómo pasa.
  Widget _avisoDeVeto(BuildContext context) {
    return FutureBuilder<List<Veto>>(
      future: _vetos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final todos = snapshot.data ?? const <Veto>[];
        final vigente = todos.where((v) => v.vigente).firstOrNull;
        final tema = Theme.of(context);

        if (vigente == null) {
          // Sin veto vigente no hay nada que avisar, salvo que lo hubo: que
          // alguien haya estado observado y ya no lo esté es parte de su
          // historia, y se lee distinto de no haberlo estado nunca.
          if (todos.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Tuvo ${todos.length} veto(s), ya levantado(s).',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Card(
            margin: EdgeInsets.zero,
            color: tema.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.block,
                        color: tema.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'PRODUCTOR VETADO',
                          style: tema.textTheme.titleMedium?.copyWith(
                            color: tema.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    vigente.motivo,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    vigente.reunion == null
                        ? 'Veto registrado desde el ${_dia(vigente.desde)}.'
                        : 'Registrado en «${vigente.reunion!.titulo}» · '
                              'desde el ${_dia(vigente.desde)}.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Qué significa en la práctica, y no solo la etiqueta: quien
                  // atiende al afiliado en la ventanilla tiene que poder
                  // explicarle por qué no se le puede hacer nada.
                  Text(
                    'Mientras el veto esté vigente, el productor queda fuera de '
                    'las listas y de los conteos del padrón. No se puede imprimir '
                    'su carnet ni registrarlo en otro sindicato.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Para quitar el veto, entrá al menú del sindicato → '
                    'Productores vetados, pulsá Levantar veto y escribí el '
                    'motivo. Al levantarlo volverá a aparecer en el padrón.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _marcaDeAguaVeto(BuildContext context) {
    return FutureBuilder<List<Veto>>(
      future: _vetos,
      builder: (context, snapshot) {
        final vetado = snapshot.data?.any((veto) => veto.vigente) ?? false;
        if (!vetado) return const SizedBox.shrink();
        return const _MarcaDeAguaVeto();
      },
    );
  }

  static String _dia(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final ficha = Scaffold(
      appBar: AppBar(
        leading: widget.alCerrar == null ? null : BackButton(onPressed: _salir),
        title: const Text('Ficha del productor'),
        actions: [
          FutureBuilder<ProductorDetalle>(
            future: _futuro,
            builder: (context, snapshot) {
              final p = snapshot.data?.productor;
              final pendiente = p != null && _requiereAtencion(p);
              return IconButton(
                key: const ValueKey('ficha-antecedentes'),
                tooltip: pendiente
                    ? 'Revisiones pendientes'
                    : 'Revisiones y antecedentes',
                onPressed: p == null
                    ? null
                    : () {
                        final contexto = _claveAntecedentes.currentContext;
                        if (contexto != null) {
                          Scrollable.ensureVisible(
                            contexto,
                            duration: const Duration(milliseconds: 250),
                            alignment: 0,
                          );
                        }
                      },
                icon: Icon(
                  pendiente ? Icons.warning_amber_rounded : Icons.history,
                  color: pendiente ? Theme.of(context).colorScheme.error : null,
                ),
              );
            },
          ),
          if (!context.accesoCentral && !context.soloFotosObservaciones)
            IconButton(
              tooltip: 'Ver e imprimir la credencial',
              onPressed: _verCredencial,
              icon: const Icon(Icons.badge_outlined),
            ),
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: FutureBuilder<ProductorDetalle>(
        future: _futuro,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              !snapshot.hasData) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            top: false,
            child: Align(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _crearEncabezado(snapshot.data!).acciones(context),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SelectionArea(
              child: CargaAsync<ProductorDetalle>(
                futuro: _futuro,
                alReintentar: _recargar,
                constructor: (context, detalle) => _contenido(context, detalle),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(child: _marcaDeAguaVeto(context)),
          ),
        ],
      ),
    );
    if (widget.alCerrar != null) return ficha;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (fueDescartado, _) {
        if (!fueDescartado) _salir();
      },
      child: ficha,
    );
  }

  _Encabezado _crearEncabezado(
    ProductorDetalle detalle, {
    Widget? fotografia,
    bool compacto = false,
  }) {
    final p = detalle.productor;
    final tieneFotografia = detalle.imagen(TipoImagen.original) != null;
    final puedeEditar = context.puede('PRODUCTORES_EDITAR');
    final puedeEliminar = context.puede('PRODUCTORES_ELIMINAR');
    final puedeSie = context.puede('SIE_REVISAR');
    final puedeImprimir = context.puede('CARNETS_IMPRIMIR');
    return _Encabezado(
      fotografia: fotografia,
      compacto: compacto,
      productor: p,
      numeroLote: detalle.lotes.isEmpty ? null : detalle.lotes.first.codigo,
      tieneFotografia: tieneFotografia,
      puedeEditar: puedeEditar,
      puedeEliminar: puedeEliminar,
      puedeSie: puedeSie,
      puedeImprimir: puedeImprimir,
      verificandoSie: _verificandoSie,
      alVerificarConSie: p.tieneSugerenciaSie
          ? () => _aceptarSugerenciaSie(p)
          : () => _verificarConSie(p),
      alEditarObservacion: () => _editarObservacion(p),
      agregandoReimpresion: _agregandoReimpresion,
      alAgregarReimpresion: () => _agregarReimpresion(p),
      alEditar: () => _editar(p),
      alCambiarEstado: () => _cambiarEstado(p, detalle.lotes.isNotEmpty),
      alEliminar: () => _eliminar(detalle),
      descargandoFicha: _descargandoFicha,
      alDescargarFicha: () => _descargarFicha(detalle),
    );
  }

  Widget _contenido(BuildContext context, ProductorDetalle detalle) {
    final p = detalle.productor;
    final puedeEditar = context.puede('PRODUCTORES_EDITAR');
    final puedeSie = context.puede('SIE_REVISAR');
    final puedeLotes =
        context.puede('LOTES_EDITAR') || context.puede('NUMERO_LOTE_EDITAR');
    final puedeImagenes =
        context.puede('IMAGENES_EDITAR') ||
        context.puede('FOTOS_PRODUCTORES_EDITAR') ||
        context.puede('FOTOS_PRODUCTORES_ACTUALIZAR');
    final puedeBorrarFoto =
        context.puede('IMAGENES_EDITAR') ||
        context.puede('FOTOS_PRODUCTORES_EDITAR');
    _nombre = p.nombreCompleto;
    final avisos = <Widget>[
      if (p.ciDuplicada) ...[
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Revisión CI: esta cédula se repite en otro productor del padrón. '
              'Todos los registros con esta CI quedan bloqueados para impresión. '
              'Corregí la cédula en las fichas correspondientes; aprobar SIE o quitar una observación no elimina este conflicto.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ),
      ],
      if (p.observado) ...[
        const SizedBox(height: 16),
        _AvisoObservacionManual(
          texto: p.observacion ?? 'Sin detalle',
          alEditar: () => _editarObservacion(p),
          permitirCambios: puedeEditar || context.puede('PRODUCTORES_OBSERVAR'),
        ),
      ],
      if (p.revisionLotePendiente) ...[
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revisión pendiente: número de lote',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (puedeLotes) ...[
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => detalle.lotes.isEmpty
                        ? _asignarParcela(p)
                        : _cambiarNumero(detalle.lotes.first),
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: const Text('Completar número de lote'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      if (_revisionSie case final revision?
          when revision.estado == EstadoRevisionSie.noDisponible) ...[
        const SizedBox(height: 16),
        _AvisoRevisionSie(revision: revision),
      ],
      if (p.revisionSieEstado case final estado?) ...[
        const SizedBox(height: 16),
        _AvisoEstadoSie(
          productor: p,
          estado: estado,
          alAceptar: () => _aceptarSugerenciaSie(p),
          alAprobarDatos: () => _aprobarDatosActualesSie(p),
          procesando: _verificandoSie,
          permitirCambios: puedeSie,
        ),
      ],
      _avisoDeVeto(context),
      if (p.tieneCorreccionPendiente) ...[
        const SizedBox(height: 16),
        _CorreccionPendiente(
          productor: p,
          alConfirmar: () => _confirmarCorreccion(p),
          permitirCambios: puedeEditar,
        ),
      ],
      const SizedBox(height: 24),
      _cargosDirectorio(context),
    ];
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, limites) {
          final horizontal = limites.maxWidth >= 840;
          final compacto = limites.maxWidth < 740 || limites.maxHeight < 560;
          final foto = ImagenesProductor(
            key: _claveFotoFicha,
            productorId: p.id,
            nombreProductor: p.nombreCompleto,
            ci: p.ci,
            imagenes: detalle.imagenes,
            editable: puedeImagenes,
            borrable: puedeBorrarFoto,
            enFicha: true,
            compacta: compacto,
            anchoFoto: compacto ? (limites.maxWidth < 360 ? 84 : 96) : 150,
            accionesAlLado: compacto,
            alCambiar: () {
              _huboCambios = true;
              _recargar();
            },
          );
          final parcela = _seccionParcela(context, detalle);
          final antecedentes = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Revisiones y antecedentes',
                key: _claveAntecedentes,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!_requiereAtencion(p) && p.revisionSieEstado == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sin revisiones pendientes.'),
                ),
              ...avisos,
            ],
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: _PanelFicha(
                hijo: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Card(
                    key: const ValueKey('ficha-integrada'),
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: EdgeInsets.all(compacto ? 8 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _crearEncabezado(
                            detalle,
                            fotografia: foto,
                            compacto: compacto,
                          ),
                          const Divider(height: 24),
                          if (horizontal)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 4, child: parcela),
                                const SizedBox(width: 20),
                                Expanded(flex: 6, child: antecedentes),
                              ],
                            )
                          else ...[
                            parcela,
                            const Divider(height: 24),
                            antecedentes,
                          ],
                        ],
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

  bool _requiereAtencion(Productor p) =>
      p.ciDuplicada ||
      p.observado ||
      p.revisionLotePendiente ||
      p.revisionSieBloqueaImpresion ||
      p.tieneCorreccionPendiente ||
      _revisionSie?.estado == EstadoRevisionSie.noDisponible;

  /// La parcela del productor: la que tiene, o el botón para darle una.
  ///
  /// Va en singular porque nadie puede tener dos a su nombre. Si alguna vez
  /// aparecieran varias —datos viejos, antes de la regla— se listan todas en
  /// vez de esconder ninguna.
  Widget _seccionParcela(BuildContext context, ProductorDetalle detalle) {
    final p = detalle.productor;
    final sinParcela = detalle.lotes.isEmpty;
    final editable = context.puede('LOTES_EDITAR');
    final numeroEditable = editable || context.puede('NUMERO_LOTE_EDITAR');
    final quitarPermitido = editable || context.puede('LOTES_DESASIGNAR');

    final seccion = _Seccion(
      titulo: 'Parcela',
      cantidad: detalle.lotes.length,
      accion: sinParcela && numeroEditable
          ? TextButton.icon(
              onPressed: () => _asignarParcela(p),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Asignar'),
            )
          : null,
      hijo: sinParcela
          ? const _Nada(
              texto:
                  'No tiene parcela a su nombre. Se le puede dar una nueva '
                  'o una del sindicato que hoy no tenga nadie.',
            )
          : Column(
              children: [
                for (final lote in detalle.lotes)
                  _FilaLote(
                    lote: lote,
                    editable: editable,
                    numeroEditable: numeroEditable,
                    quitarPermitido: quitarPermitido,
                    alAbrir: () => _abrirLote(lote),
                    alQuitar: () => _quitarParcela(lote, p),
                    alCambiarNumero: () => _cambiarNumero(lote),
                    alCambiarClasificacion: () => _cambiarClasificacion(lote),
                  ),
              ],
            ),
    );
    if (MediaQuery.sizeOf(context).height >= 700) return seccion;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sinParcela)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Parcela')),
                  ?seccion.accion,
                ],
              ),
            ),
          seccion.hijo,
        ],
      ),
    );
  }

  Future<void> _asignarParcela(Productor p) async {
    if (!context.puede('LOTES_EDITAR')) {
      if (await editarSoloNumeroParcela(context, p) && mounted) {
        _huboCambios = true;
        _recargar();
      }
      return;
    }
    if (await asignarParcela(context, p) && mounted) {
      _huboCambios = true;
      _recargar();
    }
  }

  Future<void> _quitarParcela(Lote lote, Productor p) async {
    if (await quitarParcela(context, lote, p) && mounted) {
      _huboCambios = true;
      _recargar();
    }
  }

  Future<void> _cambiarClasificacion(Lote lote) async {
    if (await cambiarClasificacionParcela(context, lote) && mounted) {
      _huboCambios = true;
      _recargar();
    }
  }

  Future<void> _cambiarNumero(Lote lote) async {
    if (!context.puede('LOTES_EDITAR')) {
      final detalle = await _futuro;
      if (!mounted) return;
      if (await editarSoloNumeroParcela(
            context,
            detalle.productor,
            lote: lote,
          ) &&
          mounted) {
        _huboCambios = true;
        _recargar();
      }
      return;
    }
    if (await cambiarNumeroParcela(context, lote) && mounted) {
      _huboCambios = true;
      _recargar();
    }
  }

  /// Cargos que ocupó en el directorio.
  ///
  /// Se dibuja con su propio FutureBuilder para que un fallo acá no impida ver
  /// el resto de la ficha: son datos complementarios.
  Widget _cargosDirectorio(BuildContext context) {
    return FutureBuilder<List<Cargo>>(
      future: _cargos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final cargos = snapshot.data ?? const <Cargo>[];
        if (cargos.isEmpty) {
          return const SizedBox.shrink();
        }

        final tema = Theme.of(context);
        return _Seccion(
          titulo: 'Cargos en el directorio',
          cantidad: cargos.length,
          hijo: Column(
            children: [
              for (final c in cargos)
                ListTile(
                  dense: true,
                  leading: Icon(
                    c.cargo == TipoCargo.ejecutivo ||
                            c.cargo == TipoCargo.secretarioGeneral
                        ? Icons.workspace_premium_outlined
                        : Icons.assignment_ind_outlined,
                    color: c.vigente
                        ? tema.colorScheme.primary
                        : tema.colorScheme.outline,
                  ),
                  // Se nombra el nivel además del lugar: "Presidente de
                  // CARRASCO" no dice si es de la federación o de un sindicato
                  // que se llama igual.
                  title: Text(
                    '${c.cargo.etiqueta} de ${c.ambitoNombre} '
                    '(${c.ambito.etiqueta.toLowerCase()})',
                  ),
                  subtitle: Text(c.periodo),
                  trailing: c.vigente
                      ? Chip(
                          label: const Text('En funciones'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: tema.colorScheme.primaryContainer,
                        )
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _salir() async {
    if (_saliendo || _agregandoReimpresion) return false;
    _saliendo = true;
    try {
      if (_editoProductorImpreso && !_reimpresionSolicitada) {
        final agregar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Agregar para reimpresión?'),
            content: const Text(
              'Editaste los datos de un productor cuyo carnet ya fue impreso. '
              '¿Querés agregarlo para reimpresión? Si no hay una fase activa, '
              'quedará reservado para la siguiente fase de impresión.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No, salir'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sí, agregar'),
              ),
            ],
          ),
        );
        if (!mounted || agregar == null) return false;
        if (agregar) {
          await PadronScope.of(
            context,
          ).productores.agregarReimpresionAFase(widget.productorId);
          _reimpresionSolicitada = true;
          _huboCambios = true;
        }
      }
      if (!mounted) return false;
      await _terminar(_huboCambios);
      return true;
    } catch (e) {
      if (mounted) mostrarError(context, e);
      return false;
    } finally {
      _saliendo = false;
    }
  }

  Future<void> _editar(Productor p) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductorFormulario(productor: p)),
    );
    if (guardado == true) {
      _huboCambios = true;
      if (p.credencialImpresa && !p.reimpresionFasePendiente) {
        _editoProductorImpreso = true;
      }
      _recargar();
    }
  }

  Future<void> _agregarReimpresion(Productor p) async {
    final cancelar = p.reimpresionFasePendiente;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.replay_outlined),
        title: Text(
          cancelar ? 'Cancelar reimpresión' : 'Agregar para reimpresión',
        ),
        content: Text(
          cancelar
              ? '¿Querés quitar a ${p.nombreCompleto} de la reimpresión pendiente? '
                    'Se conservarán sus impresiones anteriores.'
              : '${p.nombreCompleto} quedará pendiente para reimpresión. '
                    'Si no hay una fase activa, se incorporará al habilitar la siguiente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              cancelar ? 'Sí, cancelar reimpresión' : 'Agregar a la fase',
            ),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _agregandoReimpresion = true);
    try {
      final repositorio = PadronScope.of(context).productores;
      if (cancelar) {
        await repositorio.cancelarReimpresion(p.id);
      } else {
        await repositorio.agregarReimpresionAFase(p.id);
      }
      if (!mounted) return;
      _reimpresionSolicitada = !cancelar;
      if (cancelar) _editoProductorImpreso = false;
      _huboCambios = true;
      mostrarExito(
        context,
        cancelar
            ? 'Reimpresión cancelada.'
            : 'Productor agregado para reimpresión.',
      );
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _agregandoReimpresion = false);
    }
  }

  Future<void> _confirmarCorreccion(Productor p) async {
    try {
      await PadronScope.of(context).productores.confirmarCorreccionNombre(p.id);
      if (!mounted) return;
      _huboCambios = true;
      mostrarExito(context, 'Corrección de nombre confirmada');
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }
}

class _MarcaDeAguaVeto extends StatelessWidget {
  const _MarcaDeAguaVeto();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Transform.rotate(
        angle: -0.32,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'VETADO',
              style: tema.textTheme.displayLarge?.copyWith(
                color: tema.colorScheme.error.withValues(alpha: 0.20),
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ficha completa con todas las revisiones abiertas y desplazamiento común.
class _PanelFicha extends StatelessWidget {
  const _PanelFicha({required this.hijo});

  final Widget hijo;

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(primary: false, child: hijo);
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    this.fotografia,
    this.compacto = false,
    required this.productor,
    required this.numeroLote,
    required this.tieneFotografia,
    required this.puedeEditar,
    required this.puedeEliminar,
    required this.puedeSie,
    required this.puedeImprimir,
    required this.verificandoSie,
    required this.alVerificarConSie,
    required this.alEditarObservacion,
    required this.agregandoReimpresion,
    required this.alAgregarReimpresion,
    required this.alEditar,
    required this.alCambiarEstado,
    required this.alEliminar,
    required this.descargandoFicha,
    required this.alDescargarFicha,
  });
  final Productor productor;
  final Widget? fotografia;
  final bool compacto;
  final String? numeroLote;
  final bool tieneFotografia,
      puedeEditar,
      puedeEliminar,
      puedeSie,
      puedeImprimir;
  final bool verificandoSie, agregandoReimpresion, descargandoFicha;
  final VoidCallback alVerificarConSie,
      alEditarObservacion,
      alAgregarReimpresion;
  final VoidCallback alEditar, alCambiarEstado, alEliminar, alDescargarFicha;

  Widget identidad(BuildContext context, {bool compacto = false}) {
    final tema = Theme.of(context);
    final estilo =
        (compacto
                ? tema.textTheme.titleLarge?.copyWith(fontSize: 20)
                : tema.textTheme.headlineSmall)
            ?.copyWith(
              fontWeight: FontWeight.w600,
              color: productor.habilitado ? null : tema.colorScheme.outline,
            );
    final nombres = (productor.nombresCorregidos ?? productor.nombres).trim();
    final apellidos =
        (productor.apellidosCorregidos ?? productor.apellidos ?? '').trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compacto)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Datos del productor',
              style: tema.textTheme.titleMedium,
            ),
          ),
        _LineaIdentidad(
          key: const ValueKey('productor-nombres'),
          texto: nombres.isEmpty ? 'Sin nombre' : nombres,
          estilo: estilo,
        ),
        _LineaIdentidad(
          key: const ValueKey('productor-apellidos'),
          texto: apellidos.isEmpty ? 'Sin apellidos' : apellidos,
          estilo: estilo,
        ),
        const SizedBox(height: 4),
        _LineaIdentidad(
          key: const ValueKey('productor-cedula'),
          texto:
              'C.I.: ${productor.ci?.trim().isNotEmpty == true ? productor.ci : 'Sin cédula'}',
          estilo: tema.textTheme.titleMedium?.copyWith(
            fontSize: compacto ? 18 : 22,
            height: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: compacto ? 4 : 6),
        _LineaIdentidad(
          key: const ValueKey('productor-codigo'),
          texto: 'Código: ${productor.codigoPadron ?? 'Sin código'}',
          estilo: tema.textTheme.bodyMedium?.copyWith(
            fontSize: compacto ? 14 : 16,
            height: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (!compacto) ...[
          const SizedBox(height: 6),
          _LineaIdentidad(
            key: const ValueKey('productor-lote'),
            texto:
                'N.° de lote: ${numeroLote?.isNotEmpty == true ? numeroLote : 'Sin lote'}',
            estilo: tema.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 4),
        if (!productor.habilitado)
          const EtiquetaDeshabilitado()
        else
          Text(
            'Habilitado',
            style: tema.textTheme.labelMedium?.copyWith(
              color: tema.colorScheme.primary,
            ),
          ),
      ],
    );
  }

  Widget afiliacion(BuildContext context, {double? tamano}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Central: ${productor.centralNombre}',
        softWrap: true,
        overflow: TextOverflow.visible,
        style: tamano == null
            ? Theme.of(context).textTheme.bodySmall
            : Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: tamano,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
      ),
      SizedBox(height: tamano == null ? 2 : 6),
      Text(
        'Sindicato: ${productor.sindicatoNombre}',
        softWrap: true,
        overflow: TextOverflow.visible,
        style: tamano == null
            ? Theme.of(context).textTheme.bodySmall
            : Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: tamano,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
      ),
    ],
  );

  Widget acciones(BuildContext context) {
    final tema = Theme.of(context);
    return LayoutBuilder(
      builder: (context, limites) => IconButtonTheme(
        data: const IconButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(40, 40)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: WidgetStatePropertyAll(EdgeInsets.all(8)),
          ),
        ),
        child: Wrap(
          spacing: 0,
          alignment: WrapAlignment.center,
          children:
              [
                if (puedeEditar)
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: alEditar,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (puedeSie)
                  IconButton(
                    tooltip: productor.tieneSugerenciaSie
                        ? 'Aceptar sugerencia SIE'
                        : 'Verificar con SIE',
                    onPressed: verificandoSie ? null : alVerificarConSie,
                    icon: verificandoSie
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fact_check_outlined),
                  ),
                if (puedeEditar || context.puede('PRODUCTORES_OBSERVAR'))
                  IconButton(
                    tooltip: productor.observado
                        ? 'Editar observación'
                        : 'Marcar como observado',
                    onPressed: alEditarObservacion,
                    icon: Icon(
                      Icons.report_problem_outlined,
                      color: productor.observado
                          ? tema.colorScheme.error
                          : null,
                    ),
                  ),
                IconButton(
                  tooltip: descargandoFicha
                      ? 'Preparando ficha…'
                      : 'Descargar ficha de datos',
                  onPressed: descargandoFicha ? null : alDescargarFicha,
                  icon: descargandoFicha
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined),
                ),
                if (puedeImprimir && productor.credencialImpresa)
                  IconButton(
                    tooltip: productor.reimpresionFasePendiente
                        ? 'Cancelar reimpresión'
                        : 'Agregar para reimpresión',
                    onPressed: agregandoReimpresion
                        ? null
                        : alAgregarReimpresion,
                    icon: agregandoReimpresion
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.replay_outlined,
                            color: productor.reimpresionFasePendiente
                                ? Colors.orange.shade800
                                : null,
                          ),
                  ),
                if (puedeEditar)
                  IconButton(
                    tooltip: productor.habilitado
                        ? 'Deshabilitar'
                        : 'Habilitar',
                    onPressed: alCambiarEstado,
                    icon: Icon(
                      productor.habilitado
                          ? Icons.block
                          : Icons.check_circle_outline,
                    ),
                  ),
                if (puedeEliminar)
                  IconButton(
                    tooltip: 'Eliminar productor',
                    onPressed: alEliminar,
                    icon: Icon(
                      Icons.delete_outline,
                      color: tema.colorScheme.error,
                    ),
                  ),
              ].map((boton) {
                if (limites.maxWidth < 700 ||
                    MediaQuery.sizeOf(context).height < 600) {
                  return boton;
                }
                final etiqueta = switch (boton.tooltip) {
                  'Editar' => 'Editar datos',
                  'Verificar con SIE' => 'Consultar SIE',
                  'Aceptar sugerencia SIE' => 'Aceptar SIE',
                  'Marcar como observado' ||
                  'Editar observación' => 'Observaciones',
                  'Descargar ficha de datos' => 'Descargar ficha',
                  'Preparando ficha…' => 'Preparando…',
                  'Agregar para reimpresión' ||
                  'Cancelar reimpresión' => 'Reimpresión',
                  'Eliminar productor' => 'Eliminar',
                  _ => boton.tooltip ?? '',
                };
                return SizedBox(
                  width: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      boton,
                      Text(
                        etiqueta,
                        style: tema.textTheme.labelSmall,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final datosComplementarios = <Widget>[
      const SizedBox(height: 12),
      afiliacion(context, tamano: compacto ? 18 : 16),
      const SizedBox(height: 12),
      Text(
        'Fecha de creación: ${Auditoria.formatear(productor.auditoria.creadoEn) ?? 'Sin registro'}',
        style: tema.textTheme.bodySmall,
      ),
      const SizedBox(height: 4),
      Text(
        'Última modificación: ${Auditoria.formatear(productor.auditoria.editadoEn) ?? 'Sin registro'}',
        style: tema.textTheme.bodySmall,
      ),
    ];
    return Column(
      key: const ValueKey('ficha-datos'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identidad(context, compacto: compacto),
                  if (!compacto) ...datosComplementarios,
                ],
              ),
            ),
            if (fotografia != null) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: compacto ? 140 : 240,
                child: Column(
                  children: [
                    if (!compacto) ...[
                      Text('Fotografía', style: tema.textTheme.titleMedium),
                      const SizedBox(height: 8),
                    ],
                    fotografia!,
                  ],
                ),
              ),
            ],
          ],
        ),
        if (compacto) ...datosComplementarios,
      ],
    );
  }
}

/// Mantiene cada dato principal en un solo renglón y conserva el mismo estilo
/// tipográfico. Solo reduce proporcionalmente el conjunto cuando una pantalla
/// muy angosta no tiene espacio suficiente para mostrarlo completo.
class _LineaIdentidad extends StatelessWidget {
  const _LineaIdentidad({super.key, required this.texto, this.estilo});

  final String texto;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(texto, maxLines: 1, style: estilo),
  );
}

enum _AccionObservacion { guardar, quitar }

class _AvisoObservacionManual extends StatelessWidget {
  const _AvisoObservacionManual({
    required this.texto,
    required this.alEditar,
    required this.permitirCambios,
  });

  final String texto;
  final VoidCallback alEditar;
  final bool permitirCambios;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: tema.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.report_problem_outlined,
                  color: tema.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Observación manual',
                    style: tema.textTheme.titleMedium?.copyWith(
                      color: tema.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (permitirCambios)
                  TextButton(onPressed: alEditar, child: const Text('Editar')),
              ],
            ),
            const SizedBox(height: 8),
            Text(texto),
          ],
        ),
      ),
    );
  }
}

class _AvisoEstadoSie extends StatelessWidget {
  const _AvisoEstadoSie({
    required this.productor,
    required this.estado,
    required this.alAceptar,
    required this.alAprobarDatos,
    required this.procesando,
    required this.permitirCambios,
  });

  final Productor productor;
  final EstadoRevisionSiePersistida estado;
  final VoidCallback alAceptar;
  final VoidCallback alAprobarDatos;
  final bool procesando;
  final bool permitirCambios;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final advertencia = estado.esAdvertencia;
    final oscuro = tema.brightness == Brightness.dark;
    final color = advertencia
        ? (oscuro ? Colors.orange.shade900 : Colors.orange.shade100)
        : (oscuro ? Colors.green.shade900 : Colors.green.shade100);
    final sobreColor = advertencia
        ? (oscuro ? Colors.orange.shade100 : Colors.orange.shade900)
        : (oscuro ? Colors.green.shade100 : Colors.green.shade900);
    final titulo = switch (estado) {
      EstadoRevisionSiePersistida.verificado => 'Datos verificados con SIE',
      EstadoRevisionSiePersistida.corregidoSie => 'Corrección SIE aceptada',
      EstadoRevisionSiePersistida.corregidoManual =>
        'Datos corregidos manualmente',
      EstadoRevisionSiePersistida.aprobadoManual =>
        'Datos aprobados manualmente',
      EstadoRevisionSiePersistida.diferenciaPendiente =>
        'Corrección SIE pendiente',
      EstadoRevisionSiePersistida.noEncontrado => 'No encontrado en SIE',
      EstadoRevisionSiePersistida.sinCedula => 'SIE pendiente: falta cédula',
    };
    final sugerido = [
      productor.sieNombresSugeridos,
      productor.sieApellidosSugeridos,
    ].whereType<String>().where((v) => v.isNotEmpty).join(' ');

    return Card(
      margin: EdgeInsets.zero,
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  advertencia
                      ? Icons.warning_amber_rounded
                      : Icons.verified_outlined,
                  color: sobreColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titulo,
                    style: tema.textTheme.titleMedium?.copyWith(
                      color: sobreColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              productor.revisionSieMensaje ?? titulo,
              style: TextStyle(color: sobreColor),
            ),
            if (permitirCambios && sugerido.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'SIE sugiere: $sugerido',
                style: TextStyle(color: sobreColor),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: alAceptar,
                icon: const Icon(Icons.check),
                label: const Text('Aceptar sugerencia SIE'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: procesando ? null : alAprobarDatos,
                icon: const Icon(Icons.person_outline),
                label: const Text('Aprobar datos existentes'),
              ),
            ],
            if (permitirCambios &&
                estado == EstadoRevisionSiePersistida.noEncontrado) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: procesando ? null : alAprobarDatos,
                icon: procesando
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Aprobar datos'),
              ),
            ],
            if (advertencia) ...[
              const SizedBox(height: 8),
              Text(
                'No se puede imprimir el carnet mientras esta revisión esté '
                'en naranja.',
                style: TextStyle(color: sobreColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvisoRevisionSie extends StatelessWidget {
  const _AvisoRevisionSie({required this.revision});

  final RevisionSieProductor revision;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final noDisponible = revision.estado == EstadoRevisionSie.noDisponible;
    final corregida = revision.estado == EstadoRevisionSie.corregida;
    final color = noDisponible
        ? tema.colorScheme.errorContainer
        : corregida
        ? tema.colorScheme.primaryContainer
        : tema.colorScheme.secondaryContainer;
    final icono = noDisponible
        ? Icons.cloud_off_outlined
        : corregida
        ? Icons.fact_check_outlined
        : Icons.verified_outlined;

    return Card(
      margin: EdgeInsets.zero,
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    corregida
                        ? 'Datos corregidos con SIE'
                        : !revision.completada
                        ? 'Revisión SIE pendiente'
                        : 'Revisión SIE completada',
                    style: tema.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(revision.mensaje),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorreccionPendiente extends StatelessWidget {
  const _CorreccionPendiente({
    required this.productor,
    required this.alConfirmar,
    required this.permitirCambios,
  });

  final Productor productor;
  final VoidCallback alConfirmar;
  final bool permitirCambios;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final propuesto = [
      productor.nombresCorregidos ?? productor.nombres,
      productor.apellidosCorregidos ?? productor.apellidos ?? '',
    ].where((s) => s.isNotEmpty).join(' ');

    return Card(
      color: tema.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.edit_note, color: tema.colorScheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Corrección de nombre sin confirmar',
                    style: tema.textTheme.titleSmall?.copyWith(
                      color: tema.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'La revisión propone «$propuesto». Al confirmar, reemplaza '
                    'al nombre actual.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            if (permitirCambios) ...[
              const SizedBox(width: 12),
              FilledButton(
                onPressed: alConfirmar,
                child: const Text('Confirmar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    this.cantidad,
    required this.hijo,
    this.accion,
  });

  final String titulo;
  final int? cantidad;
  final Widget hijo;

  /// Botón al costado del título, cuando la sección deja hacer algo.
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(titulo, style: tema.textTheme.titleMedium)),
            if (cantidad != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tema.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$cantidad', style: tema.textTheme.labelSmall),
              ),
            ],
            ?accion,
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(padding: const EdgeInsets.all(4), child: hijo),
        ),
      ],
    );
  }
}

class _Nada extends StatelessWidget {
  const _Nada({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        texto,
        style: tema.textTheme.bodyMedium?.copyWith(
          color: tema.colorScheme.outline,
        ),
      ),
    );
  }
}

class _FilaLote extends StatelessWidget {
  const _FilaLote({
    required this.lote,
    required this.editable,
    required this.numeroEditable,
    required this.quitarPermitido,
    required this.alAbrir,
    required this.alQuitar,
    required this.alCambiarNumero,
    required this.alCambiarClasificacion,
  });
  final Lote lote;
  final bool editable, numeroEditable, quitarPermitido;
  final VoidCallback alAbrir, alQuitar, alCambiarNumero, alCambiarClasificacion;

  @override
  Widget build(BuildContext context) {
    final compacto = MediaQuery.sizeOf(context).height < 700;
    final tema = Theme.of(context);
    final acciones = <Widget>[
      if (editable)
        compacto
            ? IconButton(
                tooltip: 'Cambiar clasificación',
                onPressed: alCambiarClasificacion,
                icon: const Icon(Icons.category_outlined, size: 18),
              )
            : TextButton(
                onPressed: alCambiarClasificacion,
                child: const Text('Cambiar'),
              ),
      if (numeroEditable)
        compacto
            ? IconButton(
                tooltip: 'Cambiar número',
                onPressed: alCambiarNumero,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              )
            : TextButton.icon(
                onPressed: alCambiarNumero,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text('Cambiar número'),
              ),
      if (quitarPermitido)
        compacto
            ? IconButton(
                tooltip: 'Quitarle la parcela',
                onPressed: alQuitar,
                icon: Icon(
                  Icons.link_off,
                  size: 18,
                  color: tema.colorScheme.error,
                ),
              )
            : TextButton.icon(
                onPressed: alQuitar,
                icon: Icon(
                  Icons.link_off,
                  size: 18,
                  color: tema.colorScheme.error,
                ),
                label: const Text('Quitarle la parcela'),
              ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compacto)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: IconButtonTheme(
              data: const IconButtonThemeData(
                style: ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(40, 40)),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: WidgetStatePropertyAll(EdgeInsets.all(8)),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(child: Text('Parcela')),
                  ...acciones,
                ],
              ),
            ),
          ),
        ListTile(
          dense: true,
          visualDensity: compacto
              ? VisualDensity.compact
              : VisualDensity.standard,
          minVerticalPadding: 0,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: const Icon(Icons.grid_view_outlined),
          title: Text(
            'Número Lote: ${lote.codigo.isEmpty ? 'Sin número' : lote.codigo}',
            style: tema.textTheme.titleMedium?.copyWith(
              fontSize: compacto ? 18 : 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap:
              context.soloFotosObservaciones ||
                  (context.accesoCentral && !context.puede('LOTES_EDITAR'))
              ? null
              : alAbrir,
          subtitle: Text(
            lote.necesitaRevision && lote.estadoOriginal != null
                ? 'Estado sin reconocer, en el padrón decía «${lote.estadoOriginal}»'
                : 'Clasificación: ${lote.estado.etiqueta}',
            style: tema.textTheme.bodySmall,
          ),
          trailing: lote.necesitaRevision
              ? Tooltip(
                  message: 'Requiere revisión manual',
                  child: Icon(
                    Icons.help_outline,
                    size: 20,
                    color: tema.colorScheme.error,
                  ),
                )
              : lote.mercado == null
              ? null
              : Chip(
                  label: Text(lote.mercado!.etiqueta),
                  visualDensity: VisualDensity.compact,
                ),
        ),
        if (!compacto && acciones.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: acciones,
            ),
          ),
      ],
    );
  }
}
