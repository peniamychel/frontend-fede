import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/descargas.dart';
import '../widgets/dialogo_texto.dart';
import '../widgets/estados.dart';
import '../widgets/marca_estado.dart';
import 'imagenes_productor.dart';
import 'productor_formulario.dart';

/// Ficha completa de un productor: sus datos, sus lotes y sus observaciones.
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

  /// Nombre ya cargado, solo para nombrarlo en el aviso de la descarga. Se
  /// anota al dibujar la ficha y no dispara redibujado: no se muestra en
  /// ningún lado, lo lee el botón de la credencial.
  String? _nombre;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  Future<void> _descargarCredencial() => descargarCredencialProductor(
      context, widget.productorId, _nombre ?? 'el productor');

  Future<void> _cambiarEstado(Productor p) async {
    final cambio = await cambiarEstadoConAviso(
      context,
      nombre: p.nombreCompleto.isEmpty ? p.nombres : p.nombreCompleto,
      habilitado: p.habilitado,
      accion: (estado) =>
          PadronScope.of(context).productores.cambiarEstado(p.id, estado),
    );
    if (cambio && mounted) {
      _huboCambios = true;
      _recargar();
    }
  }

  void _recargar() {
    final repo = PadronScope.of(context).productores;
    setState(() {
      _futuro = repo.obtener(widget.productorId);
      _cargos = repo.cargos(widget.productorId);
    });
  }

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
              tooltip: 'Imprimir la credencial',
              onPressed: _descargarCredencial,
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
    _nombre = p.nombreCompleto;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        _Encabezado(
          productor: p,
          alEditar: () => _editar(p),
          alEliminar: () => _eliminar(p),
          alCambiarEstado: () => _cambiarEstado(p),
        ),
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
        _Seccion(
          titulo: 'Lotes',
          cantidad: detalle.lotes.length,
          hijo: detalle.lotes.isEmpty
              ? const _Nada(texto: 'Este productor no tiene lotes cargados.')
              : Column(
                  children: [
                    for (final lote in detalle.lotes) _FilaLote(lote: lote),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        _Seccion(
          titulo: 'Observaciones',
          cantidad: detalle.observaciones.length,
          accion: TextButton.icon(
            onPressed: () => _nuevaObservacion(p),
            icon: const Icon(Icons.add_comment_outlined, size: 18),
            label: const Text('Agregar'),
          ),
          hijo: detalle.observaciones.isEmpty
              ? const _Nada(texto: 'Sin observaciones registradas.')
              : Column(
                  children: [
                    for (final o in detalle.observaciones)
                      _FilaObservacion(
                        observacion: o,
                        alAlternar: () => _alternarObservacion(o),
                      ),
                  ],
                ),
        ),
      ],
    );
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
                    c.cargo == TipoCargo.presidente
                        ? Icons.workspace_premium_outlined
                        : Icons.assignment_ind_outlined,
                    color: c.vigente
                        ? tema.colorScheme.primary
                        : tema.colorScheme.outline,
                  ),
                  // Se nombra el nivel además del lugar: "Presidente de
                  // CARRASCO" no dice si es de la federación o de un sindicato
                  // que se llama igual.
                  title: Text('${c.cargo.etiqueta} de ${c.ambitoNombre} '
                      '(${c.ambito.etiqueta.toLowerCase()})'),
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

  Future<void> _eliminar(Productor p) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar el productor?'),
        content: Text(
          'Se va a borrar «${p.nombreCompleto}» junto con todos sus lotes y '
          'observaciones. La acción no se puede deshacer.',
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
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    try {
      await PadronScope.of(context).productores.eliminar(p.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _confirmarCorreccion(Productor p) async {
    try {
      await PadronScope.of(context)
          .productores
          .confirmarCorreccionNombre(p.id);
      if (!mounted) return;
      _huboCambios = true;
      mostrarExito(context, 'Corrección de nombre confirmada');
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _nuevaObservacion(Productor p) async {
    // El diálogo administra su propio controlador: desecharlo acá, tras el
    // await, lo dejaría inutilizable mientras la ruta todavía anima su salida.
    final mensaje = await DialogoTexto.mostrar(
      context,
      titulo: 'Nueva observación',
      etiqueta: 'Observación',
      ayuda: 'Qué hay que revisar de este productor',
      lineas: 3,
      mayusculas: false,
    );

    if (mensaje == null || mensaje.isEmpty || !mounted) return;

    try {
      await PadronScope.of(context).observaciones.crear(
            ObservacionRequest(mensaje: mensaje, productorId: p.id),
          );
      if (!mounted) return;
      _huboCambios = true;
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _alternarObservacion(Observacion o) async {
    final repo = PadronScope.of(context).observaciones;
    try {
      if (o.resuelta) {
        await repo.reabrir(o.id);
      } else {
        await repo.resolver(o.id);
      }
      if (!mounted) return;
      _huboCambios = true;
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.productor,
    required this.alEditar,
    required this.alEliminar,
    required this.alCambiarEstado,
  });

  final Productor productor;
  final VoidCallback alEditar;
  final VoidCallback alEliminar;
  final VoidCallback alCambiarEstado;

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
                              style: tema.textTheme.bodyMedium
                                  ?.copyWith(color: tema.colorScheme.outline),
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
                  icon: Icon(productor.habilitado
                      ? Icons.block
                      : Icons.check_circle_outline),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: alEditar,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  onPressed: alEliminar,
                  icon: Icon(Icons.delete_outline,
                      color: tema.colorScheme.error),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [
                _Dato(etiqueta: 'Cédula', valor: productor.ci),
                _Dato(etiqueta: 'Carné', valor: productor.carnetProductor),
                _Dato(
                  etiqueta: 'Fotografía',
                  valor: productor.tieneFoto
                      ? (productor.fotoDescripcion ?? 'Cargada')
                      : null,
                  vacio: 'Sin foto',
                ),
                _Dato(
                  etiqueta: 'Marcado',
                  valor: productor.marcado ? 'Sí' : 'No',
                ),
              ],
            ),
          ],
        ),
      ),
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
        Text(etiqueta,
            style: tema.textTheme.labelSmall
                ?.copyWith(color: tema.colorScheme.outline)),
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
        Card(child: Padding(padding: const EdgeInsets.all(4), child: hijo)),
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
        style: tema.textTheme.bodyMedium
            ?.copyWith(color: tema.colorScheme.outline),
      ),
    );
  }
}

class _FilaLote extends StatelessWidget {
  const _FilaLote({required this.lote});

  final Lote lote;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListTile(
      dense: true,
      leading: const Icon(Icons.grid_view_outlined),
      title: Text(lote.codigo.isEmpty ? 'Lote ${lote.id}' : lote.codigo),
      subtitle: Text(
        lote.necesitaRevision && lote.estadoOriginal != null
            ? 'Estado sin reconocer, en el padrón decía «${lote.estadoOriginal}»'
            : lote.estado.etiqueta,
        style: tema.textTheme.bodySmall,
      ),
      trailing: lote.necesitaRevision
          ? Tooltip(
              message: 'Requiere revisión manual',
              child: Icon(Icons.help_outline,
                  size: 20, color: tema.colorScheme.error),
            )
          : (lote.mercado != null
              ? Chip(
                  label: Text(lote.mercado!.etiqueta),
                  visualDensity: VisualDensity.compact,
                )
              : null),
    );
  }
}

class _FilaObservacion extends StatelessWidget {
  const _FilaObservacion({
    required this.observacion,
    required this.alAlternar,
  });

  final Observacion observacion;
  final VoidCallback alAlternar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListTile(
      dense: true,
      leading: Icon(
        observacion.resuelta
            ? Icons.check_circle_outline
            : Icons.radio_button_unchecked,
        color: observacion.resuelta
            ? tema.colorScheme.primary
            : tema.colorScheme.error,
      ),
      title: Text(
        observacion.mensaje,
        style: TextStyle(
          decoration:
              observacion.resuelta ? TextDecoration.lineThrough : null,
          color: observacion.resuelta ? tema.colorScheme.outline : null,
        ),
      ),
      subtitle: observacion.resueltaEn != null
          ? Text(
              'Resuelta el ${_fecha(observacion.resueltaEn!)}',
              style: tema.textTheme.bodySmall,
            )
          : null,
      trailing: TextButton(
        onPressed: alAlternar,
        child: Text(observacion.resuelta ? 'Reabrir' : 'Resolver'),
      ),
    );
  }

  static String _fecha(DateTime d) {
    final l = d.toLocal();
    final dd = l.day.toString().padLeft(2, '0');
    final mm = l.month.toString().padLeft(2, '0');
    return '$dd/$mm/${l.year}';
  }
}
