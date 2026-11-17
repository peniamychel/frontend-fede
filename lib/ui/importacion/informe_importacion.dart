import 'package:flutter/material.dart';

import '../../repositories/padron.dart';

/// Muestra el informe que devuelve el backend, sea de análisis o de ejecución.
class InformeImportacion extends StatelessWidget {
  const InformeImportacion({
    super.key,
    required this.informe,
    this.seleccionDuplicados = const {},
    this.alSeleccionar,
  });

  final ImportacionResultado informe;
  final Map<String, bool> seleccionDuplicados;
  final void Function(GrupoDuplicadoImportacion grupo, int fila, bool incluir)?
  alSeleccionar;

  bool _seleccionada(
    GrupoDuplicadoImportacion grupo,
    FilaDuplicadaImportacion fila,
  ) =>
      seleccionDuplicados['${grupo.huella}:${fila.numero}'] ??
      fila.seleccionada;

  List<ErrorFila> get _avisosSinGrupo {
    final agrupadas = informe.gruposDuplicados
        .expand((g) => g.filas.map((f) => f.numero))
        .toSet();
    return informe.avisos.where((a) => !agrupadas.contains(a.fila)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cabecera(context),
        const SizedBox(height: 12),
        _contadores(context),
        if (informe.nuevosSinLote > 0) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${informe.nuevosSinLote} productores sin N° de lote. '
                'Complétalo en su ficha antes de imprimir.',
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
        if (informe.gruposDuplicados.isNotEmpty) ...[
          const SizedBox(height: 12),
          _seleccionPorCi(context),
        ],
        if (informe.errores.isNotEmpty || _avisosSinGrupo.isNotEmpty) ...[
          const SizedBox(height: 12),
          _errores(context),
        ],
      ],
    );
  }

  Widget _seleccionPorCi(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CI repetidas en la planilla',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Desmarca las filas que no quieres importar. Si la CI deja de estar repetida, '
            'se quita el bloqueo por duplicidad.',
          ),
          if (informe.filasOmitidas > 0)
            Text(
              '${informe.filasOmitidas} fila(s) desmarcadas: no se importarán.',
            ),
          for (final grupo in informe.gruposDuplicados) ...[
            const Divider(height: 24),
            Text(
              'CI: ${grupo.ci}',
              key: ValueKey('grupo-ci-${grupo.ci}'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final fila in grupo.filas)
              CheckboxListTile(
                key: ValueKey('importar-fila-${fila.numero}'),
                contentPadding: EdgeInsets.zero,
                value: _seleccionada(grupo, fila),
                onChanged: !informe.simulacion || alSeleccionar == null
                    ? null
                    : (valor) =>
                          alSeleccionar!(grupo, fila.numero, valor ?? false),
                title: Text('Fila ${fila.numero} · ${fila.productor}'),
                subtitle: Text(
                  [
                    '${fila.central} › ${fila.sindicato}',
                    'N° lote: ${fila.numeroLote ?? 'Sin dato'}${fila.extension == null ? '' : ' ${fila.extension}'}',
                    if (fila.clasificacion?.isNotEmpty == true)
                      'Clasificación: ${fila.clasificacion}',
                    if (fila.observaciones?.isNotEmpty == true)
                      'Observación del Excel: ${fila.observaciones}',
                    if (!_seleccionada(grupo, fila))
                      'No se importará esta fila.',
                  ].join('\n'),
                ),
              ),
            for (final aviso
                in informe.avisos
                    .where((a) => grupo.filas.any((f) => f.numero == a.fila))
                    .take(1))
              Text(
                aviso.mensaje,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ],
      ),
    ),
  );

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
              etiqueta: 'Ya registrados',
              detalle: informe.simulacion
                  ? 'comparados por CI'
                  : '${informe.productoresActualizados} actualizados',
              valor: informe.comparaciones.length,
              icono: Icons.compare_arrows,
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
                    'Estas centrales no se crearán automáticamente. Créalas '
                    'manualmente con su abreviatura y vuelve a analizar la planilla.',
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
                    'Revisa que no sean errores de escritura. Solo se crearán después '
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
                'apellido y sindicato con productores registrados. Revisa si ya fueron importados.',
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
    final errores = informe.errores;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                informe.errores.isEmpty
                    ? 'Avisos de importación'
                    : 'Filas rechazadas y avisos',
                style: tema.textTheme.titleSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Las filas corresponden a la planilla de Excel.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.outline,
                ),
              ),
            ),
            if (_avisosSinGrupo.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Productores con CI repetida · Revisión CI',
                  style: tema.textTheme.titleSmall,
                ),
              ),
              for (final aviso in _avisosSinGrupo)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(aviso.productor ?? 'Fila ${aviso.fila}'),
                  subtitle: Text(
                    'Fila ${aviso.fila} · ${aviso.central} › ${aviso.sindicato}\n${aviso.mensaje}',
                  ),
                ),
            ],
            if (errores.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: errores.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = errores[i];
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
                      title: Text(
                        (e.productor ?? '').isEmpty ? e.mensaje : e.productor!,
                      ),
                      subtitle: Text(
                        [
                          if (e.productor?.isNotEmpty == true) e.mensaje,
                          if (e.ci?.isNotEmpty == true) 'CI: ${e.ci}',
                          if (e.central?.isNotEmpty == true ||
                              e.sindicato?.isNotEmpty == true)
                            [e.central, e.sindicato]
                                .whereType<String>()
                                .where((v) => v.isNotEmpty)
                                .join(' › '),
                          if (e.productor == null && e.columna != null)
                            'Columna ${e.columna}${(e.valor ?? '').isEmpty ? '' : ' · «${e.valor}»'}',
                        ].join('\n'),
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
