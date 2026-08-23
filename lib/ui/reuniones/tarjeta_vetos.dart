import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import 'decidir_vetos.dart';

/// Los vetos que se decidieron en la reunión.
///
/// Se habilitan por reunión y vienen apagados: no toda asamblea es para
/// sancionar. La mayoría es informativa o de organización, y ofrecer el veto en
/// todas invita a usarlo donde no corresponde.
///
/// Aun habilitados hace falta el acta: es el documento que respalda la
/// decisión, y sin él la sanción sería la palabra de quien la cargó.
class TarjetaVetos extends StatefulWidget {
  const TarjetaVetos({super.key, required this.reunion, required this.alCambiar});

  final Reunion reunion;
  final VoidCallback alCambiar;

  @override
  State<TarjetaVetos> createState() => _TarjetaVetosState();
}

class _TarjetaVetosState extends State<TarjetaVetos> {
  late Future<List<Veto>> _vetos;
  bool _cambiando = false;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void didUpdateWidget(TarjetaVetos anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.reunion.id != widget.reunion.id) _recargar();
  }

  void _recargar() {
    final repo = PadronScope.of(context).vetos;
    setState(() {
      _vetos = repo.deLaReunion(widget.reunion.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final habilitados = widget.reunion.vetosHabilitados;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: habilitados,
              onChanged: _cambiando ? null : (v) => _habilitar(v),
              secondary: Icon(Icons.gavel_outlined,
                  color: habilitados
                      ? tema.colorScheme.primary
                      : tema.colorScheme.outline),
              title: Text('Vetos', style: tema.textTheme.titleLarge),
              subtitle: Text(
                habilitados
                    ? 'En esta reunión se pueden decidir vetos.'
                    : 'Activalo solo si en esta asamblea se trata alguna '
                        'sanción.',
                style: tema.textTheme.bodySmall,
              ),
            ),
            if (habilitados) ...[
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Divider(),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: widget.reunion.tieneActa
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _lasDosOpciones(context),
                          const SizedBox(height: 4),
                          _listaDeVetos(context),
                        ],
                      )
                    : _Nota(
                        texto: 'Falta subir el acta. Hasta que esté, esta '
                            'reunión no puede vetar a nadie: el acta es lo que '
                            'respalda la decisión.',
                        color: tema.colorScheme.error,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Las dos direcciones de la decisión: poner y quitar.
  ///
  /// Van las dos juntas y con el mismo peso porque en una asamblea se hacen
  /// las dos cosas, a veces en la misma sesión, y ninguna es la principal.
  Widget _lasDosOpciones(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: _vetar,
            icon: const Icon(Icons.block, size: 18),
            label: const Text('Vetar a alguien'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _levantar,
            icon: const Icon(Icons.how_to_reg, size: 18),
            label: const Text('Quitar un veto'),
          ),
        ),
      ],
    );
  }

  Future<void> _vetar() async {
    if (await vetarEnLaReunion(context, widget.reunion) && mounted) {
      _recargar();
      widget.alCambiar();
    }
  }

  Future<void> _levantar() async {
    if (await levantarEnLaReunion(context, widget.reunion) && mounted) {
      _recargar();
      widget.alCambiar();
    }
  }

  Widget _listaDeVetos(BuildContext context) {
    return CargaAsync<List<Veto>>(
      futuro: _vetos,
      alReintentar: _recargar,
      constructor: (context, vetos) {
        if (vetos.isEmpty) {
          return const _Nota(
            texto: 'Todavía no se decidió ningún veto en esta reunión.',
          );
        }
        return Column(
          children: [for (final v in vetos) _fila(context, v)],
        );
      },
    );
  }

  /// Una decisión de esta reunión, en la dirección que haya sido.
  ///
  /// La lista trae las dos: a quién vetó y a quién sacó de la lista. Sin
  /// distinguirlas, «JUAN MORALES» aparecería igual habiendo sido sancionado o
  /// habiendo sido perdonado, que es lo contrario.
  Widget _fila(BuildContext context, Veto v) {
    final tema = Theme.of(context);
    final loLevantoAca = v.reunionLevanta?.id == widget.reunion.id;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        loLevantoAca ? Icons.how_to_reg : Icons.block,
        color: loLevantoAca ? tema.colorScheme.primary : tema.colorScheme.error,
      ),
      title: Text(v.productorNombre),
      subtitle: Text(
        loLevantoAca
            ? 'Sacado de la lista · ${v.motivoLevantamiento ?? ''}'
            : v.vigente
                ? 'Vetado · ${v.motivo}'
                : 'Vetado acá, ya levantado en '
                    '«${v.reunionLevanta?.titulo ?? 'otra reunión'}»',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _habilitar(bool valor) async {
    // Apagarlo con vetos ya decididos los dejaría sin la asamblea que los
    // respalda, así que se avisa antes.
    if (!valor) {
      final decididos = await _vetos;
      if (!mounted) return;
      if (decididos.isNotEmpty) {
        mostrarAviso(
          context,
          'Acá ya se decidieron ${decididos.length} veto(s)',
          detalle: 'Desactivarlo los dejaría sin la asamblea que los '
              'respalda. Para eso hay que levantarlos, en otra reunión.',
        );
        return;
      }
    }

    setState(() => _cambiando = true);
    try {
      await PadronScope.of(context).reuniones.actualizar(
            widget.reunion.id,
            ReunionRequest.desde(widget.reunion, vetosHabilitados: valor),
          );
      if (!mounted) return;
      setState(() => _cambiando = false);
      widget.alCambiar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cambiando = false);
      mostrarError(context, e);
    }
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.texto, this.color});

  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(texto,
          style: tema.textTheme.bodySmall
              ?.copyWith(color: color ?? tema.colorScheme.outline)),
    );
  }
}
