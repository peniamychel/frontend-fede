import 'package:flutter/material.dart';

import '../../repositories/padron.dart';

/// Muestra el informe que devuelve el backend, sea de análisis o de ejecución.
class InformeImportacion extends StatelessWidget {
  const InformeImportacion({super.key, required this.informe});

  final ImportacionResultado informe;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecera(context),
        const SizedBox(height: 12),
        _contadores(context),
        if (informe.productores > informe.lotes) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${informe.productores - informe.lotes} productores sin número '
                'de lote: quedan pendientes de revisión. Se conserva la '
                'clasificación declarada; completá el lote en su ficha antes '
                'de imprimir el carnet.',
              ),
            ),
          ),
        ],
        if (informe.tocaLaJerarquia) ...[
          const SizedBox(height: 12),
          _jerarquiaNueva(context),
        ],
        if (informe.posiblesDuplicados > 0) ...[
          const SizedBox(height: 12),
          _duplicados(context),
        ],
        if (informe.errores.isNotEmpty) ...[
          const SizedBox(height: 12),
          _errores(context),
        ],
      ],
    );
  }

  Widget _cabecera(BuildContext context) {
    final tema = Theme.of(context);
    final esAnalisis = informe.simulacion;

    return Card(
      color: esAnalisis
          ? tema.colorScheme.secondaryContainer
          : tema.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              esAnalisis ? Icons.visibility_outlined : Icons.check_circle,
              color: esAnalisis
                  ? tema.colorScheme.onSecondaryContainer
                  : tema.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esAnalisis
                        ? 'Vista previa · no se escribió nada'
                        : 'Importación realizada',
                    style: tema.textTheme.titleSmall?.copyWith(
                      color: esAnalisis
                          ? tema.colorScheme.onSecondaryContainer
                          : tema.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Destino ${informe.federacionNombre} · '
                    '${informe.filasLeidas} filas leídas · ${informe.duracionMs} ms',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: esAnalisis
                          ? tema.colorScheme.onSecondaryContainer
                          : tema.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contadores(BuildContext context) {
    final verbo = informe.simulacion ? 'se crearían' : 'creados';

    return LayoutBuilder(
      builder: (context, restricciones) {
        final columnas = restricciones.maxWidth >= 560 ? 3 : 2;
        return GridView.count(
          crossAxisCount: columnas,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.1,
          children: [
            _Contador(
              etiqueta: 'Productores',
              detalle: verbo,
              valor: informe.productores,
              icono: Icons.people_outline,
            ),
            _Contador(
              etiqueta: 'Lotes',
              detalle: verbo,
              valor: informe.lotes,
              icono: Icons.grid_view_outlined,
            ),
            _Contador(
              etiqueta: 'Observaciones',
              detalle: verbo,
              valor: informe.observaciones,
              icono: Icons.flag_outlined,
            ),
            _Contador(
              etiqueta: 'Filas rechazadas',
              detalle: informe.hayRechazos ? 'ver detalle abajo' : 'ninguna',
              valor: informe.filasRechazadas,
              icono: Icons.error_outline,
              alerta: informe.hayRechazos,
            ),
          ],
        );
      },
    );
  }

  Widget _jerarquiaNueva(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (informe.centralesFaltantes.isNotEmpty)
          Card(
            color: tema.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.block_outlined,
                        size: 20,
                        color: tema.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Centrales no registradas',
                        style: tema.textTheme.titleSmall?.copyWith(
                          color: tema.colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Estas centrales no se crearán automáticamente. Crealas '
                    'manualmente con su abreviatura y volvé a analizar la planilla.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final central in informe.centralesFaltantes)
                        Chip(
                          avatar: const Icon(Icons.hub_outlined, size: 16),
                          label: Text(central),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (informe.centralesFaltantes.isNotEmpty &&
            informe.sindicatosNuevos.isNotEmpty)
          const SizedBox(height: 12),
        if (informe.sindicatosNuevos.isNotEmpty)
          Card(
            color: tema.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_tree_outlined,
                        size: 20,
                        color: tema.colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sindicatos nuevos para aprobar',
                        style: tema.textTheme.titleSmall?.copyWith(
                          color: tema.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Revisá que no sean errores de escritura. Solo se crearán después '
                    'de que apruebes esta lista en el siguiente paso.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in informe.sindicatosNuevos)
                        Chip(
                          avatar: const Icon(Icons.groups_outlined, size: 16),
                          label: Text('${s.central} › ${s.sindicato}'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _duplicados(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      color: tema.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.content_copy_outlined,
              color: tema.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '${informe.posiblesDuplicados} fila(s) coinciden en nombre, '
                'apellido y sindicato con productores que ya están cargados. '
                'Puede que esta planilla ya se haya importado antes.',
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errores(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text('Filas rechazadas', style: tema.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'El número es el de la fila en Excel: abrí la planilla y andá '
                'directo ahí.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.outline,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: informe.errores.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = informe.errores[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: tema.colorScheme.errorContainer,
                      child: Text(
                        '${e.fila}',
                        style: tema.textTheme.labelSmall?.copyWith(
                          color: tema.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    title: Text(e.mensaje),
                    subtitle: e.columna == null
                        ? null
                        : Text(
                            'Columna ${e.columna}'
                            '${(e.valor ?? '').isEmpty ? '' : ' · «${e.valor}»'}',
                            style: tema.textTheme.bodySmall,
                          ),
                  );
                },
              ),
            ),
            if (informe.erroresOmitidos > 0)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Y ${informe.erroresOmitidos} error(es) más que no se '
                  'listaron.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({
    required this.etiqueta,
    required this.detalle,
    required this.valor,
    required this.icono,
    this.alerta = false,
  });

  final String etiqueta;
  final String detalle;
  final int valor;
  final IconData icono;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = alerta ? tema.colorScheme.error : tema.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  icono,
                  size: 16,
                  color: valor > 0 ? color : tema.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    etiqueta,
                    style: tema.textTheme.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$valor',
              style: tema.textTheme.headlineSmall?.copyWith(
                color: valor > 0 ? color : tema.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              detalle,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
