import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import 'impresion_credencial.dart';
import 'tarjeta_previa.dart';

/// Estado de credenciales e impresión masiva por sindicato.
/// Android y web consultan el mismo estado; el envío físico se habilita solo
/// en la aplicación nativa de Windows.
class PliegoPreviaPagina extends StatefulWidget {
  const PliegoPreviaPagina({super.key, required this.sindicato});

  final Sindicato sindicato;

  @override
  State<PliegoPreviaPagina> createState() => _PliegoPreviaPaginaState();
}

class _PliegoPreviaPaginaState extends State<PliegoPreviaPagina> {
  late Future<(PanelImpresionSindicato, EditorDisenoCredencial)> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  Future<(PanelImpresionSindicato, EditorDisenoCredencial)> _cargar() async {
    final padron = PadronScope.of(context);
    final panel = await padron.sindicatos.panelImpresion(widget.sindicato.id);
    if (!impresionDeCredencialesDisponible) {
      return (
        panel,
        EditorDisenoCredencial(
          diseno: DisenoCredencial.predeterminado(),
          campos: const [],
        ),
      );
    }
    try {
      final editor = await padron.disenoCredencial.obtener();
      return (
        panel,
        EditorDisenoCredencial(
          diseno: editor.diseno.elementos.isEmpty
              ? DisenoCredencial.predeterminado()
              : editor.diseno,
          campos: editor.campos,
          plantillaCaraUrl: editor.plantillaCaraUrl,
          plantillaReversoUrl: editor.plantillaReversoUrl,
        ),
      );
    } catch (_) {
      return (
        panel,
        EditorDisenoCredencial(
          diseno: DisenoCredencial.predeterminado(),
          campos: const [],
        ),
      );
    }
  }

  void _recargar() => setState(() => _futuro = _cargar());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Impresión · ${widget.sindicato.nombre}'),
        actions: [
          IconButton(
            tooltip: 'Actualizar cantidades',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CargaAsync<(PanelImpresionSindicato, EditorDisenoCredencial)>(
        futuro: _futuro,
        alReintentar: _recargar,
        constructor: (context, datos) => _Panel(
          panel: datos.$1,
          editor: datos.$2,
          sindicato: widget.sindicato,
          permiteImprimir: impresionDeCredencialesDisponible,
          alCambiar: _recargar,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.panel,
    required this.editor,
    required this.sindicato,
    required this.permiteImprimir,
    required this.alCambiar,
  });

  final PanelImpresionSindicato panel;
  final EditorDisenoCredencial editor;
  final Sindicato sindicato;
  final bool permiteImprimir;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Resumen del sindicato',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Cifra('Total', panel.total, Icons.groups_outlined),
            _Cifra(
              'Ya impresos',
              panel.impresos,
              Icons.print,
              color: Colors.green,
            ),
            _Cifra(
              'Faltan con foto',
              panel.faltantesConFoto,
              Icons.pending_actions_outlined,
              color: Colors.amber,
            ),
            _Cifra(
              'Sin fotografía',
              panel.sinFoto,
              Icons.no_photography_outlined,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
        if (panel.faltantesDelSindicato.isNotEmpty) ...[
          const SizedBox(height: 20),
          _FaltantesComunes(faltantes: panel.faltantesDelSindicato),
        ],
        if (permiteImprimir) ...[
          const SizedBox(height: 24),
          const _SelectorImpresoraMasiva(),
          const SizedBox(height: 28),
          Text('Acciones', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: panel.listosParaImprimir == 0
                    ? null
                    : () => _abrirFaltantes(context),
                icon: const Icon(Icons.print_outlined),
                label: Text(
                  'Impresiones faltantes (${panel.listosParaImprimir})',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: panel.candidatos.any((c) => c.seleccionable)
                    ? () => _abrirSelectiva(context)
                    : null,
                icon: const Icon(Icons.checklist_outlined),
                label: const Text('Impresión selectiva'),
              ),
              OutlinedButton.icon(
                onPressed: panel.ultimoGrupo == null
                    ? null
                    : () => _revisarUltimoGrupo(context),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Revisar última impresión'),
              ),
              OutlinedButton.icon(
                onPressed: () => _imprimirReversos(context),
                icon: const Icon(Icons.flip_outlined),
                label: const Text('Imprimir reversos'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Solo las caras impresas se contabilizan. Los reversos son iguales '
            'para todo el sindicato y no modifican el historial.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ] else ...[
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.visibility_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vista informativa. Desde Android y web podés consultar '
                      'el avance; la impresión física y la selección de la Zebra '
                      'se realizan en la aplicación para Windows.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _abrirFaltantes(BuildContext context) async {
    final cantidad = await _pedirCantidad(
      context,
      maximo: panel.listosParaImprimir,
      titulo: 'Credenciales faltantes',
      descripcion:
          'Elegí cuántas caras querés preparar. También podés imprimir todas.',
    );
    if (cantidad == null || !context.mounted) return;

    final candidatos = panel.candidatos
        .where((c) => c.impresiones == 0 && c.seleccionable)
        .take(cantidad)
        .toList(growable: false);
    final impresos = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => _SeleccionAnversosPagina(
          sindicato: sindicato,
          candidatos: candidatos,
          editor: editor,
          titulo: 'Revisar caras antes de imprimir',
          seleccionarTodosAlAbrir: true,
          permitirReimpresion: false,
        ),
      ),
    );
    if (impresos == null || impresos == 0 || !context.mounted) return;
    alCambiar();
    await _avisarImpresionEnCurso(context, impresos);
  }

  Future<void> _abrirSelectiva(BuildContext context) async {
    final impresos = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => _SeleccionAnversosPagina(
          sindicato: sindicato,
          candidatos: panel.candidatos,
          editor: editor,
          titulo: 'Impresión selectiva',
          seleccionarTodosAlAbrir: false,
          permitirReimpresion: true,
        ),
      ),
    );
    if (impresos == null || impresos == 0 || !context.mounted) return;
    alCambiar();
    await _avisarImpresionEnCurso(context, impresos);
  }

  Future<void> _revisarUltimoGrupo(BuildContext context) async {
    final grupo = panel.ultimoGrupo;
    if (grupo == null) return;
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _RevisionUltimoGrupoPagina(
          sindicato: sindicato,
          grupo: grupo,
          editor: editor,
        ),
      ),
    );
    if (cambio == true) alCambiar();
  }

  Future<void> _avisarImpresionEnCurso(
    BuildContext context,
    int cantidad,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: const Text('La impresión ya comenzó'),
      content: Text(
        'Windows envió $cantidad caras a la Zebra. No canceles el trabajo ni '
        'apagues la impresora. Si se interrumpe, usá “Revisar última impresión” '
        'para marcar solamente las tarjetas que sí salieron o cancelar todo el grupo.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );

  Future<void> _imprimirReversos(BuildContext context) async {
    final cantidad = await _pedirCantidad(
      context,
      maximo: 500,
      titulo: 'Cantidad de reversos',
      descripcion:
          'Indicá cuántas tarjetas necesitan el reverso del sindicato.',
      mostrarTodos: false,
    );
    if (cantidad != null && context.mounted) {
      await _enviarReversos(context, cantidad);
    }
  }

  Future<void> _enviarReversos(BuildContext context, int cantidad) async {
    final continuar = await _advertirImpresion(
      context,
      titulo: 'Antes de imprimir $cantidad reversos',
      mensaje:
          'Da vuelta las tarjetas para imprimir el reverso. Verificá también '
          'en el panel digital de la Zebra que la cinta alcance para $cantidad impresiones.',
    );
    if (!continuar || !context.mounted) return;
    try {
      final descarga = await PadronScope.of(
        context,
      ).sindicatos.descargarReversos(sindicato.id, cantidad);
      if (!context.mounted) return;
      await imprimirTrabajoCredencialesWindows(context, descarga);
    } catch (error) {
      if (context.mounted) mostrarError(context, error);
    }
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.titulo, this.valor, this.icono, {this.color});

  final String titulo;
  final int valor;
  final IconData icono;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icono, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$valor',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FaltantesComunes extends StatelessWidget {
  const _FaltantesComunes({required this.faltantes});

  final List<Faltante> faltantes;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Faltan datos comunes del sindicato'),
          const SizedBox(height: 8),
          for (final falta in faltantes)
            Text('• ${falta.detalle} · ${falta.donde}'),
        ],
      ),
    ),
  );
}

class _SeleccionAnversosPagina extends StatefulWidget {
  const _SeleccionAnversosPagina({
    required this.sindicato,
    required this.candidatos,
    required this.editor,
    required this.titulo,
    required this.seleccionarTodosAlAbrir,
    required this.permitirReimpresion,
  });

  final Sindicato sindicato;
  final List<CandidatoImpresionCredencial> candidatos;
  final EditorDisenoCredencial editor;
  final String titulo;
  final bool seleccionarTodosAlAbrir;
  final bool permitirReimpresion;

  @override
  State<_SeleccionAnversosPagina> createState() =>
      _SeleccionAnversosPaginaState();
}

class _SeleccionAnversosPaginaState extends State<_SeleccionAnversosPagina> {
  late final Set<int> _seleccionados;
  bool _procesando = false;
  List<int>? _pendientesDeRegistrar;

  @override
  void initState() {
    super.initState();
    _seleccionados = widget.seleccionarTodosAlAbrir
        ? widget.candidatos
              .where((candidato) => candidato.seleccionable)
              .map((candidato) => candidato.productorId)
              .toSet()
        : <int>{};
  }

  @override
  Widget build(BuildContext context) {
    final cantidad = _seleccionados.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          TextButton(
            onPressed: _procesando
                ? null
                : () => setState(() {
                    final seleccionables = widget.candidatos
                        .where((candidato) => candidato.seleccionable)
                        .map((candidato) => candidato.productorId)
                        .toSet();
                    if (_seleccionados.containsAll(seleccionables)) {
                      _seleccionados.clear();
                    } else {
                      _seleccionados.addAll(seleccionables);
                    }
                  }),
            child: Text(
              _seleccionados.containsAll(
                    widget.candidatos
                        .where((candidato) => candidato.seleccionable)
                        .map((candidato) => candidato.productorId),
                  )
                  ? 'Desmarcar todas'
                  : 'Marcar todas',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.fact_check_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Revisá la posición de la foto y los datos. Desmarcar una '
                      'credencial solo la excluye de este trabajo; no la marca como incorrecta.',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('$cantidad seleccionadas'),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: _SelectorImpresoraMasiva(),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 390,
                mainAxisExtent: 315,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
              ),
              itemCount: widget.candidatos.length,
              itemBuilder: (context, indice) {
                final candidato = widget.candidatos[indice];
                final marcado = _seleccionados.contains(candidato.productorId);
                return _CredencialSeleccionable(
                  candidato: candidato,
                  marcado: marcado,
                  editor: widget.editor,
                  alCambiar: _procesando || !candidato.seleccionable
                      ? null
                      : (valor) => setState(() {
                          if (valor) {
                            _seleccionados.add(candidato.productorId);
                          } else {
                            _seleccionados.remove(candidato.productorId);
                          }
                        }),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _procesando
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed:
                        _procesando ||
                            (_pendientesDeRegistrar == null && cantidad == 0)
                        ? null
                        : _imprimir,
                    icon: _procesando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined),
                    label: Text(
                      _pendientesDeRegistrar == null
                          ? 'Imprimir $cantidad caras'
                          : 'Registrar impresión enviada',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _imprimir() async {
    final ids = _pendientesDeRegistrar ?? _seleccionados.toList();
    if (_pendientesDeRegistrar == null) {
      final continuar = await _advertirImpresion(
        context,
        titulo: 'Antes de imprimir ${ids.length} caras',
        mensaje:
            'Verificá que haya ${ids.length} tarjetas insertadas y que el panel '
            'digital de la Zebra indique cinta suficiente. Podés cancelar para desmarcar tarjetas.',
      );
      if (!continuar || !mounted) return;
    }

    setState(() => _procesando = true);
    try {
      final repositorio = PadronScope.of(context).sindicatos;
      if (_pendientesDeRegistrar == null) {
        final descarga = await repositorio.descargarAnversosSeleccionados(
          widget.sindicato.id,
          ids,
          permitirReimpresion: widget.permitirReimpresion,
        );
        if (!mounted) return;
        final enviado = await imprimirTrabajoCredencialesWindows(
          context,
          descarga,
        );
        if (!enviado || !mounted) return;
        _pendientesDeRegistrar = ids;
      }

      await repositorio.confirmarAnversosImpresos(widget.sindicato.id, ids);
      if (!mounted) return;
      Navigator.of(context).pop(ids.length);
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }
}

class _RevisionUltimoGrupoPagina extends StatefulWidget {
  const _RevisionUltimoGrupoPagina({
    required this.sindicato,
    required this.grupo,
    required this.editor,
  });

  final Sindicato sindicato;
  final UltimoGrupoImpresionCredencial grupo;
  final EditorDisenoCredencial editor;

  @override
  State<_RevisionUltimoGrupoPagina> createState() =>
      _RevisionUltimoGrupoPaginaState();
}

class _RevisionUltimoGrupoPaginaState
    extends State<_RevisionUltimoGrupoPagina> {
  late final Set<int> _impresos;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _impresos = widget.grupo.productorIdsContabilizados.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar última impresión')),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Marcá únicamente las tarjetas que salieron físicamente de '
                      'la Zebra. Las desmarcadas dejarán de contarse como impresas. '
                      'Este control corresponde al último grupo de '
                      '${widget.grupo.total} caras enviado.',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('${_impresos.length} impresas'),
                ],
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 390,
                mainAxisExtent: 315,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
              ),
              itemCount: widget.grupo.candidatos.length,
              itemBuilder: (context, indice) {
                final candidato = widget.grupo.candidatos[indice];
                final marcado = _impresos.contains(candidato.productorId);
                return _CredencialSeleccionable(
                  candidato: candidato,
                  marcado: marcado,
                  editor: widget.editor,
                  alCambiar: _guardando
                      ? null
                      : (valor) => setState(() {
                          if (valor) {
                            _impresos.add(candidato.productorId);
                          } else {
                            _impresos.remove(candidato.productorId);
                          }
                        }),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  TextButton(
                    onPressed: _guardando
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cerrar sin cambios'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _guardando ? null : _cancelarTodo,
                    icon: const Icon(Icons.undo_outlined),
                    label: const Text('Cancelar todo el grupo'),
                  ),
                  FilledButton.icon(
                    onPressed: _guardando ? null : () => _guardar(_impresos),
                    icon: _guardando
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text('Guardar revisión (${_impresos.length})'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelarTodo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('¿Cancelar todo el grupo?'),
        content: const Text(
          'Ninguna credencial de este último trabajo quedará contabilizada como '
          'impresa. Usá esta opción solo si la Zebra no imprimió ninguna tarjeta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar todo'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) await _guardar(const <int>{});
  }

  Future<void> _guardar(Set<int> productorIds) async {
    setState(() => _guardando = true);
    try {
      await PadronScope.of(context).sindicatos.revisarUltimoGrupo(
        widget.sindicato.id,
        widget.grupo.id,
        productorIds.toList(growable: false),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

class _SelectorImpresoraMasiva extends StatefulWidget {
  const _SelectorImpresoraMasiva();

  @override
  State<_SelectorImpresoraMasiva> createState() =>
      _SelectorImpresoraMasivaState();
}

class _SelectorImpresoraMasivaState extends State<_SelectorImpresoraMasiva> {
  bool _cambiando = false;

  Future<void> _cambiar() async {
    setState(() => _cambiando = true);
    try {
      await cambiarImpresoraCredencialesWindows(context);
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = nombreImpresoraCredencialesSeleccionada;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.print_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nombre == null
                    ? 'Impresora: se seleccionará antes de enviar'
                    : 'Impresora: $nombre',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _cambiando ? null : _cambiar,
              icon: _cambiando
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.swap_horiz),
              label: Text(nombre == null ? 'Seleccionar' : 'Cambiar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CredencialSeleccionable extends StatelessWidget {
  const _CredencialSeleccionable({
    required this.candidato,
    required this.marcado,
    required this.editor,
    required this.alCambiar,
  });

  final CandidatoImpresionCredencial candidato;
  final bool marcado;
  final EditorDisenoCredencial editor;
  final ValueChanged<bool>? alCambiar;

  @override
  Widget build(BuildContext context) {
    final yaImpreso = candidato.impresiones > 0;
    final colorEstado = !candidato.seleccionable
        ? Theme.of(context).colorScheme.error
        : yaImpreso
        ? Colors.green
        : Colors.amber.shade800;
    final textoEstado = !candidato.seleccionable
        ? 'Datos incompletos'
        : yaImpreso
        ? 'Impreso · ${candidato.impresiones} ${candidato.impresiones == 1 ? 'vez' : 'veces'}'
        : 'No impreso';
    return Card(
      clipBehavior: Clip.antiAlias,
      color: marcado
          ? Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .35)
          : null,
      child: InkWell(
        onTap: alCambiar == null ? null : () => alCambiar!(!marcado),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: marcado,
                    onChanged: alCambiar == null
                        ? null
                        : (valor) => alCambiar!(valor ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidato.credencial.nombreCompleto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          textoEstado,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colorEstado,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: TarjetaPrevia(
                      previa: candidato.credencial,
                      reverso: false,
                      ancho: 330,
                      diseno: editor.diseno,
                      plantillaUrl: editor.plantillaCaraUrl,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<int?> _pedirCantidad(
  BuildContext context, {
  required int maximo,
  required String titulo,
  required String descripcion,
  bool mostrarTodos = true,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _DialogoCantidad(
      maximo: maximo,
      titulo: titulo,
      descripcion: descripcion,
      mostrarTodos: mostrarTodos,
    ),
  );
}

class _DialogoCantidad extends StatefulWidget {
  const _DialogoCantidad({
    required this.maximo,
    required this.titulo,
    required this.descripcion,
    required this.mostrarTodos,
  });

  final int maximo;
  final String titulo;
  final String descripcion;
  final bool mostrarTodos;

  @override
  State<_DialogoCantidad> createState() => _DialogoCantidadState();
}

class _DialogoCantidadState extends State<_DialogoCantidad> {
  late final TextEditingController _controlador;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _aceptar() {
    final cantidad = int.tryParse(_controlador.text.trim());
    if (cantidad == null || cantidad < 1 || cantidad > widget.maximo) {
      setState(() => _error = 'Ingresá un número entre 1 y ${widget.maximo}.');
      return;
    }
    Navigator.pop(context, cantidad);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.titulo),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.descripcion),
          const SizedBox(height: 16),
          TextField(
            controller: _controlador,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Cantidad',
              helperText: 'Máximo: ${widget.maximo}',
              errorText: _error,
            ),
            onSubmitted: (_) => _aceptar(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      if (widget.mostrarTodos)
        TextButton(
          onPressed: () => Navigator.pop(context, widget.maximo),
          child: Text('Todos (${widget.maximo})'),
        ),
      FilledButton(onPressed: _aceptar, child: const Text('Continuar')),
    ],
  );
}

Future<bool> _advertirImpresion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: Text(titulo),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Abrir impresión'),
            ),
          ],
        ),
      ) ??
      false;
}
