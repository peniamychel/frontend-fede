import 'package:flutter/material.dart';
import '../../models/importacion.dart';

/// Permite aceptar el lote del Excel, conservar el actual o dejarlo para revisión.
class RevisionCambiosImportacion extends StatelessWidget {
  const RevisionCambiosImportacion({
    super.key,
    required this.comparaciones,
    this.decisiones = const {},
    this.alDecidir,
  });
  final List<ComparacionImportacion> comparaciones;
  final Map<String, bool?> decisiones;
  final void Function(ComparacionImportacion comparacion, bool? usarExcel)?
  alDecidir;

  bool _datosEnAmbos(CambioImportacion c) =>
      !c.automatico &&
      (c.actual?.trim().isNotEmpty ?? false) &&
      c.propuesto.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final diferencias = comparaciones
        .where((p) => p.cambios.any(_datosEnAmbos))
        .toList();
    final automaticos = comparaciones
        .expand((p) => p.cambios)
        .where((c) => c.automatico)
        .toList();
    int cantidad(String campo) =>
        automaticos.where((c) => c.campo == campo).length;
    final lotes = cantidad('numeroLote');
    final resumen = [
      if (cantidad('extension') > 0)
        '${cantidad('extension')} extensión(es) faltantes',
      if (cantidad('clasificacion') > 0)
        '${cantidad('clasificacion')} clasificación(es)',
      if (cantidad('observaciones') > 0)
        '${cantidad('observaciones')} nota(s) de observado',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Productores encontrados por CI',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${diferencias.length} productores con número de lote diferente.',
            ),
            if (diferencias.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Elige qué lote conservar. Si desmarcas ambas opciones, se mantiene '
                'el actual y se anota el lote del Excel como observado.',
              ),
            ],
            if (lotes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$lotes lote(s) faltantes se completarán al importar.',
                ),
              ),
            if (resumen.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Cambios automáticos al importar: ${resumen.join(', ')}.',
                ),
              ),
            if (diferencias.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No hay números de lote diferentes.'),
              ),
            if (diferencias.isNotEmpty) ...[
              const SizedBox(height: 12),
              _lista(context, diferencias, _datosEnAmbos),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lista(
    BuildContext context,
    List<ComparacionImportacion> productores,
    bool Function(CambioImportacion) mostrar,
  ) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 600),
    child: ListView.separated(
      shrinkWrap: true,
      itemCount: productores.length,
      separatorBuilder: (_, _) => const Divider(height: 24),
      itemBuilder: (context, i) {
        final p = productores[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.productor, style: Theme.of(context).textTheme.titleSmall),
            Text('CI: ${p.ci} · Fila ${p.fila}\n${p.central} › ${p.sindicato}'),
            if (p.nombrePlanilla != p.productor)
              Text('Nombre en Excel: ${p.nombrePlanilla}'),
            for (final c in p.cambios.where(mostrar))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.etiqueta,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Sistema: ${c.actual ?? 'Sin dato'}\nExcel: ${c.propuesto}',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final usarExcel in [true, false])
                          ChoiceChip(
                            key: ValueKey('lote-${p.fila}-$usarExcel'),
                            label: Text(
                              usarExcel ? 'Aceptar Excel' : 'Conservar actual',
                            ),
                            selected:
                                (decisiones.containsKey(p.clave(c.campo))
                                    ? decisiones[p.clave(c.campo)]
                                    : false) ==
                                usarExcel,
                            onSelected: alDecidir == null
                                ? null
                                : (seleccionado) => alDecidir!(
                                    p,
                                    seleccionado ? usarExcel : null,
                                  ),
                          ),
                      ],
                    ),
                    if (decisiones.containsKey(p.clave(c.campo)) &&
                        decisiones[p.clave(c.campo)] == null)
                      Text(
                        'Se mantiene el lote actual. Nota de observado: N° lote según Excel: ${c.propuesto}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
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
