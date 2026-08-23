import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/productor_detalle_pagina.dart';
import '../widgets/estados.dart';

/// Quiénes están observados por decisión de asamblea.
///
/// Un solo buscador para las formas en que se pregunta en la práctica: con la
/// cédula en la mano, con el código de la credencial, o dictando el nombre. Y
/// un filtro por sindicato para mirar una base entera.
///
/// Por defecto muestra solo los vetos vigentes, que es lo que hace falta al
/// controlar a alguien en la puerta. El historial de los levantados está a un
/// toque.
class VetadosPagina extends StatefulWidget {
  const VetadosPagina({super.key, this.sindicato});

  /// Si viene, arranca acotado a ese sindicato.
  final Sindicato? sindicato;

  @override
  State<VetadosPagina> createState() => _VetadosPaginaState();
}

class _VetadosPaginaState extends State<VetadosPagina> {
  final _busqueda = TextEditingController();

  late Future<List<Veto>> _futuro;
  bool _soloVigentes = true;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _recargar() {
    final repo = PadronScope.of(context).vetos;
    setState(() {
      _futuro = repo.buscar(
        texto: _busqueda.text,
        sindicatoId: widget.sindicato?.id,
        vigentes: _soloVigentes,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sindicato == null
            ? 'Vetados'
            : 'Vetados de ${widget.sindicato!.nombre}'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _busqueda,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Cédula, código de credencial, nombre o apellido',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _busqueda.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _busqueda.clear();
                              _recargar();
                            },
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _recargar(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Solo los vigentes'),
                      selected: _soloVigentes,
                      onSelected: (v) {
                        setState(() => _soloVigentes = v);
                        _recargar();
                      },
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _recargar,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Buscar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CargaAsync<List<Veto>>(
              futuro: _futuro,
              alReintentar: _recargar,
              constructor: (context, vetos) {
                if (vetos.isEmpty) {
                  return SinResultados(
                    icono: Icons.verified_outlined,
                    mensaje: _busqueda.text.isEmpty
                        ? 'No hay nadie vetado.'
                        : 'Nadie vetado con «${_busqueda.text}».',
                    detalle: _soloVigentes
                        ? 'Se están mostrando solo los vetos vigentes.'
                        : 'Tampoco hay vetos levantados que coincidan.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: vetos.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _FilaVeto(
                    veto: vetos[i],
                    alAbrir: () => _abrir(vetos[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Mientras el veto rige: no se le emite credencial, no ocupa cargo y '
          'no cuenta para el quórum.',
          textAlign: TextAlign.center,
          style: tema.textTheme.bodySmall
              ?.copyWith(color: tema.colorScheme.outline),
        ),
      ),
    );
  }

  Future<void> _abrir(Veto veto) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductorDetallePagina(productorId: veto.productorId),
    ));
    if (mounted) _recargar();
  }
}

class _FilaVeto extends StatelessWidget {
  const _FilaVeto({required this.veto, required this.alAbrir});

  final Veto veto;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    // Los tres identificadores juntos: quien controla en la puerta tiene en la
    // mano uno cualquiera de ellos.
    final identifica = [
      if (veto.codigoPadron != null) veto.codigoPadron!,
      if (veto.ci != null && veto.ci!.isNotEmpty) 'C.I. ${veto.ci}',
      if (veto.codigo != null) veto.codigo!,
    ].join(' · ');

    return ListTile(
      isThreeLine: true,
      leading: Icon(
        veto.vigente ? Icons.block : Icons.check_circle_outline,
        color: veto.vigente ? tema.colorScheme.error : tema.colorScheme.primary,
      ),
      title: Text(veto.productorNombre),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (identifica.isNotEmpty)
            Text(identifica, style: tema.textTheme.bodySmall),
          Text(veto.ruta, style: tema.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            veto.vigente
                ? veto.motivo
                : 'Levantado el ${_fecha(veto.hasta)} · ${veto.motivoLevantamiento ?? ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tema.textTheme.bodySmall?.copyWith(
              color: veto.vigente ? tema.colorScheme.error : tema.colorScheme.outline,
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: alAbrir,
    );
  }

  static String _fecha(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
