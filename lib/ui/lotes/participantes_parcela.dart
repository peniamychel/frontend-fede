import 'package:flutter/material.dart';

import '../../models/lote.dart';

/// Participaciones vigentes del mismo número de lote, no tenencias históricas.
class ParticipantesParcela extends StatelessWidget {
  const ParticipantesParcela({super.key, required this.participaciones});

  final List<Lote> participaciones;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final lote in participaciones)
        Padding(
          key: ValueKey('participacion-lote-${lote.id}'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lote.tenedor!.nombre,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text('Clasificación: ${lote.estado.etiqueta}'),
              Text('Extensión: ${lote.letraParticipacion ?? 'Sin extensión'}'),
            ],
          ),
        ),
    ],
  );
}
