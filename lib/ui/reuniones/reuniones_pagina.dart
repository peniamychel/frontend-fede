import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import 'reunion_formulario.dart';
import 'reunion_pagina.dart';

/// Todas las reuniones, de la más reciente a la más antigua.
class ReunionesPagina extends StatefulWidget {
  const ReunionesPagina({super.key});

  @override
  State<ReunionesPagina> createState() => _ReunionesPaginaState();
}

class _ReunionesPaginaState extends State<ReunionesPagina> {
  late Future<List<Reunion>> _futuro;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    final repo = PadronScope.of(context).reuniones;
    setState(() {
      _futuro = repo.listar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reuniones'),
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
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Convocar'),
      ),
      body: CargaAsync<List<Reunion>>(
        futuro: _futuro,
        alReintentar: _recargar,
        constructor: (context, lista) {
          if (lista.isEmpty) {
            return SinResultados(
              icono: Icons.event_note_outlined,
              mensaje: 'Todavía no hay reuniones.',
              detalle: 'Convocá una y después pasá lista escaneando los '
                  'carnets.',
              accion: FilledButton.icon(
                onPressed: _crear,
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Convocar reunión'),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: lista.length,
            itemBuilder: (context, i) => _Fila(
              reunion: lista[i],
              alAbrir: () => _abrir(lista[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _crear() async {
    final creada = await Navigator.of(context).push<Reunion>(
      MaterialPageRoute(builder: (_) => const ReunionFormulario()),
    );
    if (creada == null || !mounted) return;
    _recargar();
    _abrir(creada);
  }

  Future<void> _abrir(Reunion reunion) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReunionPagina(reunionId: reunion.id)),
    );
    if (mounted) _recargar();
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.reunion, required this.alAbrir});

  final Reunion reunion;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListTile(
      leading: Icon(iconoDeTipo(reunion.tipo),
          color: reunion.cerrada
              ? tema.colorScheme.outline
              : tema.colorScheme.primary),
      title: Text(reunion.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${reunion.tipo.etiqueta} · ${reunion.convocanteNombre}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(reunion.fechaCorta,
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.outline)),
        ],
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${reunion.presentes} / ${reunion.convocados}',
              style: tema.textTheme.titleMedium),
          Text(reunion.cerrada ? 'Cerrada' : 'Abierta',
              style: tema.textTheme.labelSmall?.copyWith(
                color: reunion.cerrada
                    ? tema.colorScheme.outline
                    : tema.colorScheme.primary,
              )),
        ],
      ),
      onTap: alAbrir,
    );
  }
}

IconData iconoDeTipo(TipoReunion tipo) => switch (tipo) {
      TipoReunion.sindicato => Icons.groups_outlined,
      TipoReunion.ampliado => Icons.hub_outlined,
      TipoReunion.dirigentesCentral => Icons.groups_2_outlined,
      TipoReunion.dirigentesFederacion => Icons.account_balance_outlined,
    };
