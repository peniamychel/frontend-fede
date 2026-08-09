import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/productor_detalle_pagina.dart';
import '../widgets/estados.dart';

enum TipoDuplicado {
  cedula('Cédulas duplicadas', 'cédula', Icons.badge_outlined),
  carnet('Carnés duplicados', 'carné', Icons.credit_card_outlined);

  const TipoDuplicado(this.titulo, this.singular, this.icono);

  final String titulo;
  final String singular;
  final IconData icono;
}

/// Documentos asignados a más de una persona.
///
/// El backend devuelve solo los documentos repetidos, no los productores: hay
/// que pedir por separado quiénes comparten cada uno. Por eso la lista se
/// despliega bajo demanda, y no de golpe.
class DuplicadosPagina extends StatefulWidget {
  const DuplicadosPagina({super.key, required this.tipo});

  final TipoDuplicado tipo;

  @override
  State<DuplicadosPagina> createState() => _DuplicadosPaginaState();
}

class _DuplicadosPaginaState extends State<DuplicadosPagina> {
  late Future<List<String>> _futuro;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    final repo = PadronScope.of(context).productores;
    setState(() {
      _futuro = switch (widget.tipo) {
        TipoDuplicado.cedula => repo.cedulasDuplicadas(),
        TipoDuplicado.carnet => repo.carnetsDuplicados(),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tipo.titulo),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CargaAsync<List<String>>(
        futuro: _futuro,
        alReintentar: _recargar,
        constructor: (context, documentos) {
          if (documentos.isEmpty) {
            return SinResultados(
              icono: Icons.check_circle_outline,
              mensaje: 'No hay ${widget.tipo.singular}s repetidas.',
              detalle: 'Cada documento corresponde a una sola persona.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: documentos.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _FilaDuplicado(
              documento: documentos[i],
              tipo: widget.tipo,
            ),
          );
        },
      ),
    );
  }
}

class _FilaDuplicado extends StatefulWidget {
  const _FilaDuplicado({required this.documento, required this.tipo});

  final String documento;
  final TipoDuplicado tipo;

  @override
  State<_FilaDuplicado> createState() => _FilaDuplicadoState();
}

class _FilaDuplicadoState extends State<_FilaDuplicado> {
  Future<List<Productor>>? _futuro;

  void _cargarSiHaceFalta(bool abierto) {
    if (!abierto || _futuro != null) return;
    final repo = PadronScope.of(context).productores;
    setState(() {
      _futuro = switch (widget.tipo) {
        TipoDuplicado.cedula => repo.porCedula(widget.documento),
        TipoDuplicado.carnet => repo.porCarnet(widget.documento),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Icon(widget.tipo.icono),
      title: Text(
        widget.documento,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
      ),
      subtitle: Text('Tocá para ver quiénes comparten esta ${widget.tipo.singular}'),
      onExpansionChanged: _cargarSiHaceFalta,
      children: [
        if (_futuro == null)
          const SizedBox(height: 4)
        else
          CargaAsync<List<Productor>>(
            futuro: _futuro!,
            constructor: (context, productores) {
              if (productores.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No se encontraron productores.'),
                );
              }
              return Column(
                children: [
                  for (final p in productores)
                    ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.only(left: 56, right: 16),
                      leading: const Icon(Icons.person_outline, size: 20),
                      title: Text(
                        p.nombreCompleto.isEmpty
                            ? p.nombres
                            : p.nombreCompleto,
                      ),
                      subtitle: Text(p.ruta),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductorDetallePagina(productorId: p.id),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
