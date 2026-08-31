import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../credenciales/credencial_previa_pagina.dart';
import '../lotes/lote_pagina.dart';
import '../widgets/estados.dart';
import 'asignar_parcela.dart';
import '../widgets/marca_estado.dart';
import 'imagenes_productor.dart';
import 'productor_formulario.dart';

/// Ficha completa de un productor: sus datos, sus lotes y sus imágenes.
class ProductorDetallePagina extends StatefulWidget {
  const ProductorDetallePagina({super.key, required this.productorId});

  final int productorId;

  @override
  State<ProductorDetallePagina> createState() => _ProductorDetallePaginaState();
}

class _ProductorDetallePaginaState extends State<ProductorDetallePagina> {
  late Future<ProductorDetalle> _futuro;

  /// Va aparte de la ficha porque es otra consulta: el historial de cargos
  /// incluye los de sindicatos anteriores y no cuelga del detalle.
  late Future<List<Cargo>> _cargos;

  /// Si se tocó algo, la lista de la que venimos tiene que recargarse.
  bool _huboCambios = false;

  /// Resultado de la revisión automática realizada durante esta apertura.
  RevisionSieProductor? _revisionSie;

  bool _verificandoSie = false;

  /// Nombre ya cargado, solo para nombrarlo en el aviso de la descarga. Se
  /// anota al dibujar la ficha y no dispara redibujado: no se muestra en
  /// ningún lado, lo lee el botón de la credencial.
  String? _nombre;

  @override
  void initState() {
    super.initState();
    _recargar();
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
    if (cambio == true && mounted) _recargar();
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

  /// El borrado se reserva para registros cargados por error. Un productor con
  /// una parcela vigente no se puede borrar: primero se debe traspasar o
  /// quitar la parcela desde esta misma ficha.
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
        icon: const Icon(Icons.delete_forever_outlined),
        title: Text('¿Eliminar a $nombre?'),
        content: const Text(
          'Esta acción es definitiva. Se borrarán su ficha, fotografías, '
          'cargos, vetos y el historial de tenencias. Los lotes no se '
          'eliminan.',
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
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await PadronScope.of(context).productores.eliminar(productor.id);
      if (!mounted) return;
      _huboCambios = true;
      Navigator.of(context).pop(true);
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
      _futuro = _cargarDetalleConRevision(padron);
      _cargos = padron.productores.cargos(widget.productorId);
      _vetos = padron.vetos.historialDe(widget.productorId);
    });
  }

  Future<ProductorDetalle> _cargarDetalleConRevision(Padron padron) async {
    var detalle = await padron.productores.obtener(widget.productorId);
    if (!detalle.productor.revisionSiePendiente) return detalle;

    final resultado = await padron.productores.revisarImportadoConSie(
      widget.productorId,
    );
    _revisionSie = resultado;
    if (resultado.datosModificados) _huboCambios = true;

    // Al completar se relee la ficha para mostrar de inmediato la corrección.
    // Una caída temporal no apaga la marca: se intentará en otra apertura.
    if (resultado.completada) {
      detalle = await padron.productores.obtener(widget.productorId);
    }
    return detalle;
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
          'diferentes, se corregirán automáticamente en la ficha.',
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
      final resultado = await padron.productores.verificarManualmenteConSie(
        productor.id,
      );
      if (!mounted) return;
      if (resultado.datosModificados) _huboCambios = true;
      setState(() {
        _revisionSie = resultado;
        _verificandoSie = false;
        if (resultado.completada) {
          _futuro = padron.productores.obtener(widget.productorId);
        }
      });
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
                          'Observado por la asamblea',
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
                    'Decidido en «${vigente.reunion?.titulo ?? ''}» · '
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
                    'Mientras el veto siga: su credencial no se emite, no puede '
                    'ocupar un cargo, y no se le toma asistencia ni cuenta para '
                    'el quórum de las reuniones.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sigue siendo afiliado: conserva su parcela, su código y su '
                    'historial. Para sacarlo de la lista hace falta otra '
                    'asamblea que lo decida, con su acta.',
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

  static String _dia(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (fueDescartado, _) {
        if (!fueDescartado) Navigator.of(context).pop(_huboCambios);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ficha del productor'),
          actions: [
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
        body: CargaAsync<ProductorDetalle>(
          futuro: _futuro,
          alReintentar: _recargar,
          constructor: (context, detalle) => _contenido(context, detalle),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, ProductorDetalle detalle) {
    final p = detalle.productor;
    final tieneFotografia = detalle.imagen(TipoImagen.original) != null;
    _nombre = p.nombreCompleto;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        _Encabezado(
          productor: p,
          tieneFotografia: tieneFotografia,
          verificandoSie: _verificandoSie,
          alVerificarConSie: () => _verificarConSie(p),
          alEditar: () => _editar(p),
          alCambiarEstado: () => _cambiarEstado(p, detalle.lotes.isNotEmpty),
          alEliminar: () => _eliminar(detalle),
        ),
        if (_revisionSie case final revision?) ...[
          const SizedBox(height: 16),
          _AvisoRevisionSie(revision: revision),
        ],
        _avisoDeVeto(context),
        if (p.tieneCorreccionPendiente) ...[
          const SizedBox(height: 16),
          _CorreccionPendiente(
            productor: p,
            alConfirmar: () => _confirmarCorreccion(p),
          ),
        ],
        const SizedBox(height: 24),
        _cargosDirectorio(context),
        const SizedBox(height: 24),
        _Seccion(
          titulo: 'Fotografías',
          cantidad: detalle.imagenes.length,
          hijo: Padding(
            padding: const EdgeInsets.all(8),
            child: ImagenesProductor(
              productorId: p.id,
              imagenes: detalle.imagenes,
              alCambiar: () {
                _huboCambios = true;
                _recargar();
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        _seccionParcela(context, detalle),
      ],
    );
  }

  /// La parcela del productor: la que tiene, o el botón para darle una.
  ///
  /// Va en singular porque nadie puede tener dos a su nombre. Si alguna vez
  /// aparecieran varias —datos viejos, antes de la regla— se listan todas en
  /// vez de esconder ninguna.
  Widget _seccionParcela(BuildContext context, ProductorDetalle detalle) {
    final p = detalle.productor;
    final sinParcela = detalle.lotes.isEmpty;

    return _Seccion(
      titulo: 'Parcela',
      cantidad: detalle.lotes.length,
      accion: sinParcela
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
                    alAbrir: () => _abrirLote(lote),
                    alQuitar: () => _quitarParcela(lote, p),
                    alCambiarNumero: () => _cambiarNumero(lote),
                    alCambiarClasificacion: () => _cambiarClasificacion(lote),
                  ),
              ],
            ),
    );
  }

  Future<void> _asignarParcela(Productor p) async {
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

  Future<void> _editar(Productor p) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductorFormulario(productor: p)),
    );
    if (guardado == true) {
      _huboCambios = true;
      _recargar();
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

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.productor,
    required this.tieneFotografia,
    required this.verificandoSie,
    required this.alVerificarConSie,
    required this.alEditar,
    required this.alCambiarEstado,
    required this.alEliminar,
  });

  final Productor productor;
  final bool tieneFotografia;
  final bool verificandoSie;
  final VoidCallback alVerificarConSie;
  final VoidCallback alEditar;
  final VoidCallback alCambiarEstado;
  final VoidCallback alEliminar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productor.nombreCompleto.isEmpty
                            ? productor.nombres
                            : productor.nombreCompleto,
                        style: tema.textTheme.headlineSmall?.copyWith(
                          color: productor.habilitado
                              ? null
                              : tema.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (!productor.habilitado) ...[
                            const EtiquetaDeshabilitado(),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              productor.ruta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tema.textTheme.bodyMedium?.copyWith(
                                color: tema.colorScheme.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: productor.habilitado ? 'Deshabilitar' : 'Habilitar',
                  onPressed: alCambiarEstado,
                  icon: Icon(
                    productor.habilitado
                        ? Icons.block
                        : Icons.check_circle_outline,
                  ),
                ),
                IconButton(
                  tooltip: 'Verificar con SIE',
                  onPressed: verificandoSie ? null : alVerificarConSie,
                  icon: verificandoSie
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fact_check_outlined),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: alEditar,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Eliminar productor',
                  onPressed: alEliminar,
                  icon: Icon(
                    Icons.delete_outline,
                    color: tema.colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [
                // Primero el código: es con lo que se lo nombra.
                _Dato(
                  etiqueta: 'Código',
                  valor: productor.codigoPadron,
                  vacio:
                      'Falta el número de la federación o la sigla de la '
                      'central',
                ),
                _Dato(etiqueta: 'Cédula', valor: productor.ci),
                if (!tieneFotografia)
                  const _Dato(etiqueta: 'Fotografía', vacio: 'Sin foto'),
                _Dato(
                  etiqueta: 'Fecha de creación',
                  valor: Auditoria.formatear(productor.auditoria.creadoEn),
                ),
                _EstadoImpresionCredencial(productor: productor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoImpresionCredencial extends StatelessWidget {
  const _EstadoImpresionCredencial({required this.productor});

  final Productor productor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (estado, color) = !productor.credencialLista
        ? ('Incompleta o sin fotografía', tema.colorScheme.outline)
        : productor.credencialImpresa
        ? ('Impresa', Colors.green)
        : ('Lista, pendiente de impresión', Colors.amber.shade700);
    final ultima = Auditoria.formatear(productor.credencialUltimaImpresion);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Impresión de credencial',
          style: tema.textTheme.labelSmall?.copyWith(
            color: tema.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print, size: 18, color: color),
            const SizedBox(width: 6),
            Text(estado, style: tema.textTheme.bodyLarge),
          ],
        ),
        if (productor.credencialImpresiones > 0)
          Text(
            '${productor.credencialImpresiones} impresión(es) de la cara'
            '${ultima == null ? '' : ' · Última: $ultima'}',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, this.valor, this.vacio = '—'});

  final String etiqueta;
  final String? valor;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final hay = valor != null && valor!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etiqueta,
          style: tema.textTheme.labelSmall?.copyWith(
            color: tema.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hay ? valor! : vacio,
          style: tema.textTheme.bodyLarge?.copyWith(
            color: hay ? null : tema.colorScheme.outline,
            fontStyle: hay ? null : FontStyle.italic,
          ),
        ),
      ],
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
                        : noDisponible
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
  });

  final Productor productor;
  final VoidCallback alConfirmar;

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
            const SizedBox(width: 12),
            FilledButton(
              onPressed: alConfirmar,
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.cantidad,
    required this.hijo,
    this.accion,
  });

  final String titulo;
  final int cantidad;
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
            Text(titulo, style: tema.textTheme.titleMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tema.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$cantidad', style: tema.textTheme.labelSmall),
            ),
            const Spacer(),
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
    required this.alAbrir,
    required this.alQuitar,
    required this.alCambiarNumero,
    required this.alCambiarClasificacion,
  });

  final Lote lote;
  final VoidCallback alAbrir;
  final VoidCallback alQuitar;
  final VoidCallback alCambiarNumero;
  final VoidCallback alCambiarClasificacion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      children: [
        ListTile(
          dense: true,
          leading: Icon(
            lote.tieneUbicacion
                ? Icons.location_on_outlined
                : Icons.grid_view_outlined,
          ),
          title: Text(lote.codigo.isEmpty ? 'Lote ${lote.id}' : lote.codigo),
          onTap: alAbrir,
          subtitle: Text(
            [
              lote.necesitaRevision && lote.estadoOriginal != null
                  ? 'Estado sin reconocer, en el padrón decía '
                        '«${lote.estadoOriginal}»'
                  : lote.estado.etiqueta,
              if (lote.superficie != null) lote.superficieTexto,
            ].join(' · '),
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
              : (lote.mercado != null
                    ? Chip(
                        label: Text(lote.mercado!.etiqueta),
                        visualDensity: VisualDensity.compact,
                      )
                    : null),
        ),
        // La clasificación pertenece a esta participación: otra persona con
        // el mismo número puede tener una opción distinta.
        Padding(
          padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
          child: Row(
            children: [
              Icon(
                Icons.category_outlined,
                size: 18,
                color: tema.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Clasificación: ${lote.estado.etiqueta}',
                  style: tema.textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: alCambiarClasificacion,
                child: const Text('Cambiar'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: alCambiarNumero,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text('Cambiar número'),
              ),
              TextButton.icon(
                onPressed: alQuitar,
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('Quitarle la parcela'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
