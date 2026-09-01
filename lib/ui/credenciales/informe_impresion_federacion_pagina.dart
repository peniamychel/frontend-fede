import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/descargas.dart';
import '../widgets/estados.dart';
import 'informe_impresion_central_pagina.dart';

/// Informe del avance de impresión de todas las centrales de la federación.
class InformeImpresionFederacionPagina extends StatefulWidget {
  const InformeImpresionFederacionPagina({super.key, required this.federacion});

  final Federacion federacion;

  @override
  State<InformeImpresionFederacionPagina> createState() =>
      _InformeImpresionFederacionPaginaState();
}

class _InformeImpresionFederacionPaginaState
    extends State<InformeImpresionFederacionPagina> {
  late Future<InformeImpresionFederacion> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  Future<InformeImpresionFederacion> _cargar() => PadronScope.of(
    context,
  ).centrales.informeImpresionFederacion(widget.federacion.id);

  Future<void> _recargar() async {
    final futuro = _cargar();
    setState(() => _futuro = futuro);
    await futuro;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avance general de impresión'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: CargaAsync<InformeImpresionFederacion>(
        futuro: _futuro,
        alReintentar: _recargar,
        constructor: (context, informe) => _ContenidoFederacion(
          informe: informe,
          federacion: widget.federacion,
          alRecargar: _recargar,
        ),
      ),
    );
  }
}

class _ContenidoFederacion extends StatelessWidget {
  const _ContenidoFederacion({
    required this.informe,
    required this.federacion,
    required this.alRecargar,
  });

  final InformeImpresionFederacion informe;
  final Federacion federacion;
  final Future<void> Function() alRecargar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return RefreshIndicator(
      onRefresh: alRecargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            informe.federacion,
            style: tema.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${informe.centrales} centrales · ${informe.sindicatos} sindicatos · '
            '${informe.total} productores',
          ),
          const SizedBox(height: 18),
          _AvanceFederacion(informe: informe),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () =>
                  descargarInformeImpresionFederacion(context, federacion),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generar informe PDF'),
            ),
          ),
          const SizedBox(height: 18),
          Text('Resumen por central', style: tema.textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'La tabla compara la cantidad de sindicatos, productores y el avance de impresión.',
          ),
          const SizedBox(height: 10),
          _TablaCentrales(centrales: informe.detalle),
          const SizedBox(height: 28),
          Text('Detalle por central', style: tema.textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Todos los detalles aparecen colapsados. Seleccioná una central para revisar su informe.',
          ),
          const SizedBox(height: 10),
          if (informe.detalle.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('La federación todavía no tiene centrales.'),
              ),
            )
          else
            for (final central in informe.detalle) ...[
              _DetalleCentral(informe: central, federacion: federacion),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AvanceFederacion extends StatelessWidget {
  const _AvanceFederacion({required this.informe});

  final InformeImpresionFederacion informe;

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
                const Expanded(child: Text('Avance de toda la federación')),
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

class _TablaCentrales extends StatelessWidget {
  const _TablaCentrales({required this.centrales});

  final List<InformeImpresionCentral> centrales;

  @override
  Widget build(BuildContext context) {
    if (centrales.isEmpty) return const SizedBox.shrink();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Central')),
            DataColumn(label: Text('Sindicatos'), numeric: true),
            DataColumn(label: Text('Productores'), numeric: true),
            DataColumn(label: Text('Impresos'), numeric: true),
            DataColumn(label: Text('No impresos'), numeric: true),
            DataColumn(label: Text('Avance'), numeric: true),
          ],
          rows: [
            for (final central in centrales)
              DataRow(
                cells: [
                  DataCell(Text(central.central)),
                  DataCell(Text('${central.sindicatos}')),
                  DataCell(Text('${central.total}')),
                  DataCell(Text('${central.impresos}')),
                  DataCell(Text('${central.pendientes}')),
                  DataCell(Text('${_porcentaje(central.porcentajeAvance)}%')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DetalleCentral extends StatelessWidget {
  const _DetalleCentral({required this.informe, required this.federacion});

  final InformeImpresionCentral informe;
  final Federacion federacion;

  @override
  Widget build(BuildContext context) {
    final porcentaje = informe.porcentajeAvance.clamp(0, 100);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('informe-central-${informe.centralId}'),
        initiallyExpanded: false,
        title: Text(
          informe.central,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${informe.sindicatos} sindicatos · ${informe.total} productores · '
          '${_porcentaje(informe.porcentajeAvance)}%',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          LinearProgressIndicator(
            value: porcentaje / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Cifra(etiqueta: 'Productores', valor: informe.total),
              _Cifra(etiqueta: 'Impresos', valor: informe.impresos),
              _Cifra(etiqueta: 'No impresos', valor: informe.pendientes),
              _Cifra(
                etiqueta: 'Pendientes con foto',
                valor: informe.pendientesConFoto,
              ),
              _Cifra(etiqueta: 'Sin foto', valor: informe.sinFoto),
              _Cifra(
                etiqueta: 'Listos para imprimir',
                valor: informe.listosParaImprimir,
              ),
              _Cifra(
                etiqueta: 'Sindicatos sin sello',
                valor: informe.sindicatosSinSello,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Detalle por sindicato',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 6),
          if (informe.detalle.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Esta central todavía no tiene sindicatos.'),
            )
          else
            for (final sindicato in informe.detalle)
              _FilaSindicato(informe: sindicato),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InformeImpresionCentralPagina(
                    central: Central(
                      id: informe.centralId,
                      nombre: informe.central,
                      federacionId: federacion.id,
                      federacionNombre: federacion.nombre,
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Abrir informe completo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.etiqueta, required this.valor});

  final String etiqueta;
  final int valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$valor',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(etiqueta),
        ],
      ),
    );
  }
}

class _FilaSindicato extends StatelessWidget {
  const _FilaSindicato({required this.informe});

  final AvanceImpresionSindicato informe;

  @override
  Widget build(BuildContext context) {
    final color = informe.selloCargado
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.groups_outlined, color: color),
      title: Text(informe.sindicato),
      subtitle: Text(
        '${informe.impresos} de ${informe.total} impresos · '
        '${informe.sinFoto} sin foto',
      ),
      trailing: Text(
        '${_porcentaje(informe.porcentajeAvance)}%',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _porcentaje(num valor) {
  final decimal = valor.toDouble();
  return decimal == decimal.roundToDouble()
      ? '${decimal.round()}'
      : decimal.toStringAsFixed(1);
}
