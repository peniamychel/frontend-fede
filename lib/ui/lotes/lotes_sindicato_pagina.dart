import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import 'lote_formulario.dart';
import 'lote_pagina.dart';
import 'sistemas_pagina.dart';

/// Las parcelas de un sindicato.
///
/// Es la puerta de entrada a los lotes, y por eso vive colgada del sindicato y
/// no del productor: la tierra pertenece al sindicato, y una parcela sin
/// tenedor tiene que poder encontrarse igual.
class LotesSindicatoPagina extends StatefulWidget {
  const LotesSindicatoPagina({super.key, required this.sindicato});

  final Sindicato sindicato;

  @override
  State<LotesSindicatoPagina> createState() => _LotesSindicatoPaginaState();
}

class _LotesSindicatoPaginaState extends State<LotesSindicatoPagina> {
  late Future<List<Lote>> _futuro;
  bool _soloSinTenedor = false;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    final repo = PadronScope.of(context).lotes;
    setState(() {
      _futuro = repo.listar(sindicatoId: widget.sindicato.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Parcelas'),
            Text(widget.sindicato.nombre,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sistemas',
            onPressed: _verSistemas,
            icon: const Icon(Icons.settings_outlined),
          ),
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
        label: const Text('Nueva parcela'),
      ),
      body: CargaAsync<List<Lote>>(
        futuro: _futuro,
        alReintentar: _recargar,
        constructor: (context, todos) {
          if (todos.isEmpty) {
            return SinResultados(
              icono: Icons.crop_landscape,
              mensaje: 'Este sindicato no tiene parcelas cargadas.',
              detalle: 'Cargá la primera y después vas a poder ubicarla en el '
                  'mapa, medirla y traspasarla.',
              accion: FilledButton.icon(
                onPressed: _crear,
                icon: const Icon(Icons.add),
                label: const Text('Nueva parcela'),
              ),
            );
          }

          final visibles =
              _soloSinTenedor ? todos.where((l) => !l.tieneTenedor).toList() : todos;

          return Column(
            children: [
              _Resumen(
                lotes: todos,
                soloSinTenedor: _soloSinTenedor,
                alFiltrar: (v) => setState(() => _soloSinTenedor = v),
              ),
              const Divider(height: 1),
              Expanded(
                child: visibles.isEmpty
                    ? const SinResultados(
                        icono: Icons.check_circle_outline,
                        mensaje: 'Todas las parcelas tienen tenedor.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 88),
                        itemCount: visibles.length,
                        itemBuilder: (context, i) => _Fila(
                          lote: visibles[i],
                          alAbrir: () => _abrir(visibles[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _crear() async {
    final creado = await Navigator.of(context).push<Lote>(
      MaterialPageRoute(
        builder: (_) => LoteFormulario(sindicato: widget.sindicato),
      ),
    );
    if (creado == null || !mounted) return;
    _recargar();
    _abrir(creado);
  }

  Future<void> _abrir(Lote lote) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LotePagina(loteId: lote.id)),
    );
    if (mounted) _recargar();
  }

  Future<void> _verSistemas() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SistemasPagina(sindicato: widget.sindicato),
      ),
    );
    if (mounted) _recargar();
  }
}

/// Cuántas hay, cuánto suman y cuántas están sin dueño.
class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.lotes,
    required this.soloSinTenedor,
    required this.alFiltrar,
  });

  final List<Lote> lotes;
  final bool soloSinTenedor;
  final ValueChanged<bool> alFiltrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sinTenedor = lotes.where((l) => !l.tieneTenedor).length;
    final medidas = lotes.where((l) => l.superficie != null);
    final hectareas =
        medidas.fold<double>(0, (suma, l) => suma + (l.superficie ?? 0));
    final ubicadas = lotes.where((l) => l.tieneUbicacion).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _Cifra(valor: '${lotes.length}', etiqueta: 'parcelas'),
              _Cifra(
                valor: medidas.isEmpty
                    ? '—'
                    : hectareas.toStringAsFixed(1).replaceFirst('.0', ''),
                etiqueta: medidas.length == lotes.length
                    ? 'hectáreas'
                    : 'ha (${medidas.length} de ${lotes.length} medidas)',
              ),
              _Cifra(valor: '$ubicadas', etiqueta: 'en el mapa'),
              _Cifra(valor: '$sinTenedor', etiqueta: 'sin tenedor'),
            ],
          ),
          if (sinTenedor > 0) ...[
            const SizedBox(height: 8),
            FilterChip(
              label: Text('Solo las que no tiene nadie ($sinTenedor)'),
              selected: soloSinTenedor,
              onSelected: alFiltrar,
            ),
          ],
          if (lotes.isNotEmpty && medidas.length < lotes.length) ...[
            const SizedBox(height: 6),
            Text(
              'Sin medir no es lo mismo que cero: el padrón original no trae la '
              'superficie.',
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(valor, style: tema.textTheme.titleLarge),
        const SizedBox(width: 4),
        Text(etiqueta,
            style: tema.textTheme.bodySmall
                ?.copyWith(color: tema.colorScheme.outline)),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.lote, required this.alAbrir});

  final Lote lote;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListTile(
      leading: Icon(
        lote.tieneUbicacion ? Icons.location_on : Icons.crop_landscape,
        color: lote.tieneUbicacion
            ? tema.colorScheme.primary
            : tema.colorScheme.outline,
      ),
      title: Text(lote.codigo.isEmpty ? 'Parcela ${lote.id}' : lote.codigo),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lote.tenedor?.nombre ?? 'Sin tenedor',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: lote.tieneTenedor ? null : tema.colorScheme.outline,
              fontStyle: lote.tieneTenedor ? null : FontStyle.italic,
            ),
          ),
          Text(
            [
              lote.superficieTexto,
              lote.estado.etiqueta,
              if (lote.tieneSistema) 'Sistema ${lote.sistema!.codigo}',
            ].join(' · '),
            style: tema.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: alAbrir,
    );
  }
}
