import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/productor_detalle_pagina.dart';
import '../widgets/estados.dart';

/// Lotes cuyo estado de origen el backend no pudo normalizar.
///
/// La columna útil acá es [Lote.estadoOriginal]: es el texto tal como estaba en
/// la planilla, y es lo que hay que interpretar a mano.
class LotesDesconocidosPagina extends StatefulWidget {
  const LotesDesconocidosPagina({super.key});

  @override
  State<LotesDesconocidosPagina> createState() =>
      _LotesDesconocidosPaginaState();
}

class _LotesDesconocidosPaginaState extends State<LotesDesconocidosPagina> {
  late Future<List<Lote>> _futuro;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    setState(() {
      _futuro = PadronScope.of(context).lotes.estadoDesconocido();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes sin reconocer'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CargaAsync<List<Lote>>(
        futuro: _futuro,
        alReintentar: _recargar,
        constructor: (context, lotes) {
          if (lotes.isEmpty) {
            return const SinResultados(
              icono: Icons.check_circle_outline,
              mensaje: 'Todos los estados se reconocieron.',
              detalle: 'No hay lotes pendientes de interpretar.',
            );
          }

          // Agrupar por el texto original convierte una lista larga en unas
          // pocas decisiones: cada escritura distinta se resuelve una vez.
          final porTexto = <String, List<Lote>>{};
          for (final lote in lotes) {
            final clave = (lote.estadoOriginal ?? '').trim();
            porTexto.putIfAbsent(clave.isEmpty ? '(vacío)' : clave, () => [])
                .add(lote);
          }
          final claves = porTexto.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${lotes.length} lotes con ${claves.length} escrituras '
                    'distintas sin reconocer. Resolviendo cada escritura se '
                    'arreglan todos sus lotes de una vez.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final clave in claves)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    shape: const Border(),
                    leading: const Icon(Icons.help_outline),
                    title: Text(
                      '«$clave»',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    subtitle: Text('${porTexto[clave]!.length} lotes'),
                    children: [
                      for (final lote in porTexto[clave]!)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.grid_view_outlined),
                          title: Text(lote.codigo.isEmpty
                              ? 'Lote ${lote.id}'
                              : lote.codigo),
                          // Un lote puede no tener tenedor: la parcela existe
                          // igual, y decir de qué sindicato es sigue ubicándola.
                          subtitle: Text(lote.tenedor == null
                              ? '${lote.sindicatoNombre} · sin tenedor'
                              : '${lote.sindicatoNombre} · '
                                  '${lote.tenedor!.nombre}'),
                          trailing: lote.tenedor == null
                              ? null
                              : const Icon(Icons.chevron_right, size: 20),
                          onTap: lote.tenedor == null
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProductorDetallePagina(
                                        productorId:
                                            lote.tenedor!.productorId,
                                      ),
                                    ),
                                  ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
