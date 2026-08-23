import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/dialogo_nombre_numero.dart';
import '../widgets/estados.dart';

/// Los sistemas: el agregado que una parcela puede tener, y que se traslada.
///
/// Se listan aparte de las parcelas porque tienen vida propia: se venden, pasan
/// de un lote a otro, y pueden estar sin instalar.
class SistemasPagina extends StatefulWidget {
  const SistemasPagina({super.key, this.sindicato});

  /// Si viene, arranca mostrando los instalados en ese sindicato.
  final Sindicato? sindicato;

  @override
  State<SistemasPagina> createState() => _SistemasPaginaState();
}

class _SistemasPaginaState extends State<SistemasPagina> {
  late Future<List<Sistema>> _futuro;

  /// 0 = todos, 1 = los del sindicato, 2 = disponibles.
  int _filtro = 0;

  @override
  void initState() {
    super.initState();
    _filtro = widget.sindicato != null ? 1 : 0;
    _recargar();
  }

  void _recargar() {
    final repo = PadronScope.of(context).sistemas;
    setState(() {
      _futuro = switch (_filtro) {
        1 => repo.listar(sindicatoId: widget.sindicato!.id),
        2 => repo.listar(disponibles: true),
        _ => repo.listar(),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistemas'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo sistema'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                if (widget.sindicato != null)
                  ChoiceChip(
                    label: Text('En ${widget.sindicato!.nombre}'),
                    selected: _filtro == 1,
                    onSelected: (_) => _cambiarFiltro(1),
                  ),
                ChoiceChip(
                  label: const Text('Disponibles'),
                  selected: _filtro == 2,
                  onSelected: (_) => _cambiarFiltro(2),
                ),
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filtro == 0,
                  onSelected: (_) => _cambiarFiltro(0),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CargaAsync<List<Sistema>>(
              futuro: _futuro,
              alReintentar: _recargar,
              constructor: (context, sistemas) {
                if (sistemas.isEmpty) {
                  return SinResultados(
                    icono: Icons.settings_outlined,
                    mensaje: _filtro == 2
                        ? 'No hay sistemas sin instalar.'
                        : 'Todavía no hay sistemas cargados.',
                    detalle: 'Un sistema se da de alta con su código y después '
                        'se instala en una parcela.',
                    accion: FilledButton.icon(
                      onPressed: _crear,
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo sistema'),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: sistemas.length,
                  itemBuilder: (context, i) => _Fila(
                    sistema: sistemas[i],
                    alRetirar: () => _retirar(sistemas[i]),
                    alHistorial: () => _historial(sistemas[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _cambiarFiltro(int v) {
    setState(() => _filtro = v);
    _recargar();
  }

  Future<void> _crear() async {
    // Se reusa el diálogo de dos campos: un sistema es código más descripción,
    // exactamente la misma forma.
    final datos = await DialogoNombreNumero.mostrar(
      context,
      titulo: 'Nuevo sistema',
      etiquetaNombre: 'Código',
      segundo: const SegundoCampo(etiqueta: 'Descripción'),
      textoAceptar: 'Crear',
    );
    if (datos == null || !mounted) return;

    try {
      await PadronScope.of(context)
          .sistemas
          .crear(SistemaRequest(codigo: datos.nombre, descripcion: datos.numero));
      if (!mounted) return;
      mostrarExito(context, 'Sistema ${datos.nombre} creado');
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _retirar(Sistema sistema) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Retirar el sistema?'),
        content: Text(
          '${sistema.codigo} sale del lote ${sistema.lote!.codigo} y queda '
          'disponible. El período en ese lote se cierra y queda en el historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await PadronScope.of(context).sistemas.trasladar(
            sistema.id,
            null,
            const TraspasoRequest(motivo: MotivoTraspaso.otro),
          );
      if (!mounted) return;
      mostrarExito(context, '${sistema.codigo} quedó disponible');
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _historial(Sistema sistema) async {
    final List<Tenencia> periodos;
    try {
      periodos = await PadronScope.of(context).sistemas.historial(sistema.id);
    } catch (e) {
      if (mounted) mostrarError(context, e);
      return;
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Por dónde pasó ${sistema.codigo}'),
        content: SizedBox(
          width: 460,
          child: periodos.isEmpty
              ? const Text('Nunca estuvo instalado en una parcela.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in periodos)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(p.vigente
                            ? Icons.place
                            : Icons.place_outlined),
                        title: Text('Lote ${p.conQuien}'),
                        subtitle: Text([
                          p.periodo,
                          if (p.motivoEtiqueta != null) p.motivoEtiqueta!,
                        ].join(' · ')),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.sistema,
    required this.alRetirar,
    required this.alHistorial,
  });

  final Sistema sistema;
  final VoidCallback alRetirar;
  final VoidCallback alHistorial;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final donde = sistema.lote;

    return ListTile(
      leading: Icon(
        donde == null ? Icons.inventory_2_outlined : Icons.settings,
        color: donde == null
            ? tema.colorScheme.outline
            : tema.colorScheme.primary,
      ),
      title: Text(sistema.codigo),
      subtitle: Text(
        donde == null
            ? 'Disponible, sin instalar'
            : 'Lote ${donde.codigo} · ${donde.sindicato}'
                '${donde.tenedor == null ? '' : ' · ${donde.tenedor}'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Historial',
            onPressed: alHistorial,
            icon: const Icon(Icons.history, size: 20),
          ),
          if (donde != null)
            IconButton(
              tooltip: 'Retirar del lote',
              onPressed: alRetirar,
              icon: const Icon(Icons.eject_outlined, size: 20),
            ),
        ],
      ),
    );
  }
}
