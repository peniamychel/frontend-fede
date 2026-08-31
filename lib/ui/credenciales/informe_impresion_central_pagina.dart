import 'package:flutter/material.dart';

import '../../core/guardar_archivo.dart';
import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/descargas.dart';
import '../widgets/estados.dart';

/// Informe global del avance de impresión de todos los sindicatos de una central.
class InformeImpresionCentralPagina extends StatefulWidget {
  const InformeImpresionCentralPagina({super.key, required this.central});

  final Central central;

  @override
  State<InformeImpresionCentralPagina> createState() =>
      _InformeImpresionCentralPaginaState();
}

class _InformeImpresionCentralPaginaState
    extends State<InformeImpresionCentralPagina> {
  late Future<_DatosPagina> _futuro;
  bool _descargandoNominal = false;

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  Future<_DatosPagina> _cargar() async {
    final repositorio = PadronScope.of(context).centrales;
    final avance = await repositorio.informeImpresion(widget.central.id);
    final ids = avance.detalle.map((fila) => fila.sindicatoId).toList();
    final nominal = await repositorio.informeNominalImpresion(
      widget.central.id,
      ids,
    );
    return _DatosPagina(avance: avance, nominal: nominal);
  }

  Future<void> _recargar() async {
    final futuro = _cargar();
    setState(() => _futuro = futuro);
    await futuro;
  }

  Future<void> _descargarNominal(List<int> sindicatoIds) async {
    setState(() => _descargandoNominal = true);
    try {
      final descarga = await PadronScope.of(context).centrales
          .descargarInformeNominalImpresion(widget.central.id, sindicatoIds);
      await guardarArchivo(
        descarga.bytes,
        descarga.nombreArchivo,
        descarga.tipoMime,
      );
      if (mounted) mostrarExito(context, 'Informe nominal descargado en PDF.');
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _descargandoNominal = false);
    }
  }

  Future<void> _elegirYDescargar(_DatosPagina datos) async {
    final seleccion = await showDialog<Set<int>>(
      context: context,
      builder: (context) => _DialogoSindicatos(
        sindicatos: datos.avance.detalle,
        seleccionados: datos.avance.detalle
            .map((fila) => fila.sindicatoId)
            .toSet(),
      ),
    );
    if (seleccion == null || seleccion.isEmpty || !mounted) return;
    final ids = seleccion.toList(growable: false)..sort();
    await _descargarNominal(ids);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avance de impresión'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CargaAsync<_DatosPagina>(
        futuro: _futuro,
        alReintentar: _recargar,
        constructor: (context, datos) => _Contenido(
          datos: datos,
          central: widget.central,
          descargandoNominal: _descargandoNominal,
          alRecargar: _recargar,
          alDescargarNominal: () => _descargarNominal(
            datos.avance.detalle.map((fila) => fila.sindicatoId).toList(),
          ),
          alElegirNominal: () => _elegirYDescargar(datos),
        ),
      ),
    );
  }
}

class _DatosPagina {
  const _DatosPagina({required this.avance, required this.nominal});

  final InformeImpresionCentral avance;
  final InformeNominalImpresionCentral nominal;

  InformeNominalSindicato? nominalDe(int sindicatoId) {
    for (final sindicato in nominal.sindicatos) {
      if (sindicato.sindicatoId == sindicatoId) return sindicato;
    }
    return null;
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.datos,
    required this.central,
    required this.descargandoNominal,
    required this.alRecargar,
    required this.alDescargarNominal,
    required this.alElegirNominal,
  });

  final _DatosPagina datos;
  final Central central;
  final bool descargandoNominal;
  final Future<void> Function() alRecargar;
  final Future<void> Function() alDescargarNominal;
  final Future<void> Function() alElegirNominal;

  @override
  Widget build(BuildContext context) {
    final informe = datos.avance;
    final tema = Theme.of(context);
    return RefreshIndicator(
      onRefresh: alRecargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            informe.central,
            style: tema.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text('${informe.federacion} · ${informe.sindicatos} sindicatos'),
          const SizedBox(height: 20),
          _AvanceGeneral(informe: informe),
          const SizedBox(height: 12),
          _AccionesInformes(
            descargandoNominal: descargandoNominal,
            alDescargarGeneral: () =>
                descargarInformeImpresionCentral(context, central),
            alDescargarPlanilla: () =>
                descargarPlanillaRecoleccionDirectorio(context, central),
            alDescargarNominal: alDescargarNominal,
            alElegirNominal: alElegirNominal,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Cifra(
                etiqueta: 'Total',
                valor: informe.total,
                icono: Icons.badge_outlined,
              ),
              _Cifra(
                etiqueta: 'Impresos',
                valor: informe.impresos,
                icono: Icons.print_outlined,
                color: Colors.green,
              ),
              _Cifra(
                etiqueta: 'No impresos',
                valor: informe.pendientes,
                icono: Icons.pending_actions_outlined,
                color: Colors.amber.shade800,
              ),
              _Cifra(
                etiqueta: 'Pendientes con foto',
                valor: informe.pendientesConFoto,
                icono: Icons.photo_outlined,
              ),
              _Cifra(
                etiqueta: 'Sin foto',
                valor: informe.sinFoto,
                icono: Icons.no_photography_outlined,
                color: tema.colorScheme.error,
              ),
              _Cifra(
                etiqueta: 'Listos para imprimir',
                valor: informe.listosParaImprimir,
                icono: Icons.task_alt_outlined,
              ),
              _Cifra(
                etiqueta: 'Sindicatos sin sello',
                valor: informe.sindicatosSinSello,
                icono: Icons.approval_outlined,
                color: informe.sindicatosSinSello == 0
                    ? Colors.green
                    : tema.colorScheme.error,
              ),
            ],
          ),
          if (informe.sindicatosSinSello > 0) ...[
            const SizedBox(height: 12),
            _SellosPendientes(
              sindicatos: informe.detalle
                  .where((fila) => !fila.selloCargado)
                  .map((fila) => fila.sindicato)
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 28),
          Text('Detalle por sindicato', style: tema.textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Seleccioná un sindicato para desplegar sus listas nominales.',
          ),
          const SizedBox(height: 10),
          if (informe.detalle.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Esta central todavía no tiene sindicatos.'),
              ),
            )
          else
            for (final fila in informe.detalle) ...[
              _Sindicato(
                fila: fila,
                nominal: datos.nominalDe(fila.sindicatoId),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AccionesInformes extends StatelessWidget {
  const _AccionesInformes({
    required this.descargandoNominal,
    required this.alDescargarGeneral,
    required this.alDescargarPlanilla,
    required this.alDescargarNominal,
    required this.alElegirNominal,
  });

  final bool descargandoNominal;
  final Future<void> Function() alDescargarGeneral;
  final Future<void> Function() alDescargarPlanilla;
  final Future<void> Function() alDescargarNominal;
  final Future<void> Function() alElegirNominal;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generar informes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: alDescargarGeneral,
                  icon: const Icon(Icons.assessment_outlined),
                  label: const Text('Informe general'),
                ),
                OutlinedButton.icon(
                  onPressed: alDescargarPlanilla,
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Planilla de sellos y firmas'),
                ),
                FilledButton.tonalIcon(
                  onPressed: descargandoNominal ? null : alDescargarNominal,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('Informe nominal completo'),
                ),
                OutlinedButton.icon(
                  onPressed: descargandoNominal ? null : alElegirNominal,
                  icon: descargandoNominal
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.checklist_outlined),
                  label: const Text('Informe nominal por sindicatos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvanceGeneral extends StatelessWidget {
  const _AvanceGeneral({required this.informe});

  final InformeImpresionCentral informe;

  @override
  Widget build(BuildContext context) {
    final porcentaje = informe.porcentajeAvance.clamp(0, 100);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Avance general')),
                Text(
                  '${_porcentaje(porcentaje)}%',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: porcentaje / 100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 8),
            Text(
              '${informe.impresos} de ${informe.total} credenciales impresas',
            ),
          ],
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    this.color,
  });

  final String etiqueta;
  final int valor;
  final IconData icono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ancho = (MediaQuery.sizeOf(context).width - 42) / 2;
    return SizedBox(
      width: ancho.clamp(150, 260),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icono, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$valor',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(etiqueta, maxLines: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sindicato extends StatelessWidget {
  const _Sindicato({required this.fila, required this.nominal});

  final AvanceImpresionSindicato fila;
  final InformeNominalSindicato? nominal;

  @override
  Widget build(BuildContext context) {
    final porcentaje = fila.porcentajeAvance.clamp(0, 100);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey('detalle-sindicato-${fila.sindicatoId}'),
        initiallyExpanded: false,
        title: Text(
          fila.sindicato,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${fila.impresos} impresos · ${fila.pendientes} no impresos'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    key: ValueKey('avance-sindicato-${fila.sindicatoId}'),
                    value: porcentaje / 100,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_porcentaje(porcentaje)}%',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              Text('Total: ${fila.total}'),
              Text('Impresos: ${fila.impresos}'),
              Text('No impresos: ${fila.pendientes}'),
              Text('Con foto: ${fila.pendientesConFoto}'),
              Text('Sin foto: ${fila.sinFoto}'),
              Text('Listos: ${fila.listosParaImprimir}'),
              Text(
                fila.selloCargado ? 'Sello: cargado' : 'Sello: falta cargar',
                style: TextStyle(
                  color: fila.selloCargado
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          if (nominal == null)
            const Text(
              'No se pudo cargar el detalle nominal de este sindicato.',
            )
          else ...[
            _ListaNominal(
              titulo: 'Carnets impresos',
              filas: nominal!.impresos,
              impresos: true,
            ),
            const SizedBox(height: 14),
            _ListaNominal(
              titulo: 'No impresos por datos faltantes',
              filas: nominal!.faltantesDatos,
              impresos: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _SellosPendientes extends StatelessWidget {
  const _SellosPendientes({required this.sindicatos});

  final List<String> sindicatos;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Card(
      color: colores.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.approval_outlined, color: colores.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sindicatos que todavía no tienen sello',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colores.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    sindicatos.join(', '),
                    style: TextStyle(color: colores.onErrorContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaNominal extends StatelessWidget {
  const _ListaNominal({
    required this.titulo,
    required this.filas,
    required this.impresos,
  });

  final String titulo;
  final List<FilaInformeImpresion> filas;
  final bool impresos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$titulo (${filas.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        if (filas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No hay registros en esta sección.'),
          )
        else
          for (final fila in filas)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                impresos ? Icons.print : Icons.warning_amber_outlined,
                color: impresos
                    ? Colors.green
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text(fila.nombreCompleto),
              subtitle: Text(
                impresos
                    ? 'C.I. ${fila.ci.isEmpty ? 'Sin cédula' : fila.ci}'
                    : fila.datosFaltantes.join(', '),
              ),
            ),
      ],
    );
  }
}

class _DialogoSindicatos extends StatefulWidget {
  const _DialogoSindicatos({
    required this.sindicatos,
    required this.seleccionados,
  });

  final List<AvanceImpresionSindicato> sindicatos;
  final Set<int> seleccionados;

  @override
  State<_DialogoSindicatos> createState() => _DialogoSindicatosState();
}

class _DialogoSindicatosState extends State<_DialogoSindicatos> {
  late Set<int> _seleccion;

  @override
  void initState() {
    super.initState();
    _seleccion = {...widget.seleccionados};
  }

  @override
  Widget build(BuildContext context) {
    final todos = _seleccion.length == widget.sindicatos.length;
    return AlertDialog(
      title: const Text('Seleccionar sindicatos'),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            CheckboxListTile(
              value: todos,
              tristate: true,
              title: const Text('Toda la central'),
              onChanged: (_) => setState(() {
                _seleccion = todos
                    ? <int>{}
                    : widget.sindicatos.map((s) => s.sindicatoId).toSet();
              }),
            ),
            const Divider(),
            for (final sindicato in widget.sindicatos)
              CheckboxListTile(
                value: _seleccion.contains(sindicato.sindicatoId),
                title: Text(sindicato.sindicato),
                subtitle: Text('${sindicato.total} productores'),
                onChanged: (valor) => setState(() {
                  if (valor ?? false) {
                    _seleccion.add(sindicato.sindicatoId);
                  } else {
                    _seleccion.remove(sindicato.sindicatoId);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _seleccion.isEmpty
              ? null
              : () => Navigator.pop(context, _seleccion),
          child: const Text('Descargar PDF'),
        ),
      ],
    );
  }
}

String _porcentaje(num valor) => valor.toStringAsFixed(1);
