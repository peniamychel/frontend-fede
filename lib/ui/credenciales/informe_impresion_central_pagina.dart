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
  bool _descargandoPreImpresion = false;
  bool _cambiandoFase = false;
  final Set<int> _descargandoFases = <int>{};

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
    final fases = await repositorio.estadoFasesImpresion(widget.central.id);
    return _DatosPagina(avance: avance, nominal: nominal, fases: fases);
  }

  Future<void> _recargar() async {
    final futuro = _cargar();
    setState(() => _futuro = futuro);
    await futuro;
  }

  Future<void> _descargarPreImpresion() async {
    setState(() => _descargandoPreImpresion = true);
    try {
      final descarga = await PadronScope.of(
        context,
      ).centrales.descargarInformePreImpresion(widget.central.id);
      await guardarArchivo(
        descarga.bytes,
        descarga.nombreArchivo,
        descarga.tipoMime,
      );
      if (mounted) mostrarExito(context, 'Informe pre-impresión descargado.');
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _descargandoPreImpresion = false);
    }
  }

  Future<void> _habilitarFase(int numero) async {
    final aceptar = await _confirmar(
      titulo: 'Habilitar ${ordinalFase(numero)} fase de impresión',
      mensaje:
          'Mientras esta fase esté abierta, Windows podrá imprimir carnets. '
          'Los productores pendientes y los preparados para reimpresión '
          'quedarán controlados dentro de esta fase.',
      accion: 'Habilitar fase',
    );
    if (!aceptar || !mounted) return;
    setState(() => _cambiandoFase = true);
    try {
      await PadronScope.of(
        context,
      ).centrales.habilitarFaseImpresion(widget.central.id);
      if (!mounted) return;
      mostrarExito(context, '${ordinalFase(numero)} fase habilitada.');
      await _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cambiandoFase = false);
    }
  }

  Future<void> _cerrarFase(FaseImpresionCarnet fase) async {
    final aceptar = await _confirmar(
      titulo: 'Cerrar ${ordinalFase(fase.numero)} fase',
      mensaje:
          'Después de cerrarla ya no se podrán registrar impresiones en esta '
          'fase. Sus pendientes pasarán a la próxima fase cuando la habilites.',
      accion: 'Cerrar fase',
    );
    if (!aceptar || !mounted) return;
    setState(() => _cambiandoFase = true);
    try {
      await PadronScope.of(
        context,
      ).centrales.cerrarFaseImpresion(widget.central.id, fase.id);
      if (!mounted) return;
      mostrarExito(context, '${ordinalFase(fase.numero)} fase cerrada.');
      await _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _cambiandoFase = false);
    }
  }

  Future<void> _descargarFase(FaseImpresionCarnet fase) async {
    setState(() => _descargandoFases.add(fase.id));
    try {
      final descarga = await PadronScope.of(
        context,
      ).centrales.descargarInformeFase(widget.central.id, fase.id);
      await guardarArchivo(
        descarga.bytes,
        descarga.nombreArchivo,
        descarga.tipoMime,
      );
      if (mounted) {
        mostrarExito(
          context,
          'Informe de la ${ordinalFase(fase.numero)} fase descargado.',
        );
      }
    } catch (e) {
      if (mounted) mostrarError(context, e);
    } finally {
      if (mounted) setState(() => _descargandoFases.remove(fase.id));
    }
  }

  Future<bool> _confirmar({
    required String titulo,
    required String mensaje,
    required String accion,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.print_outlined),
          title: Text(titulo),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(accion),
            ),
          ],
        ),
      ) ??
      false;

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
          descargandoPreImpresion: _descargandoPreImpresion,
          cambiandoFase: _cambiandoFase,
          descargandoFases: _descargandoFases,
          alRecargar: _recargar,
          alDescargarPreImpresion: _descargarPreImpresion,
          alHabilitarFase: _habilitarFase,
          alCerrarFase: _cerrarFase,
          alDescargarFase: _descargarFase,
        ),
      ),
    );
  }
}

class _DatosPagina {
  const _DatosPagina({
    required this.avance,
    required this.nominal,
    required this.fases,
  });

  final InformeImpresionCentral avance;
  final InformeNominalImpresionCentral nominal;
  final EstadoFasesImpresionCentral fases;

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
    required this.descargandoPreImpresion,
    required this.cambiandoFase,
    required this.descargandoFases,
    required this.alRecargar,
    required this.alDescargarPreImpresion,
    required this.alHabilitarFase,
    required this.alCerrarFase,
    required this.alDescargarFase,
  });

  final _DatosPagina datos;
  final Central central;
  final bool descargandoPreImpresion;
  final bool cambiandoFase;
  final Set<int> descargandoFases;
  final Future<void> Function() alRecargar;
  final Future<void> Function() alDescargarPreImpresion;
  final Future<void> Function(int numero) alHabilitarFase;
  final Future<void> Function(FaseImpresionCarnet fase) alCerrarFase;
  final Future<void> Function(FaseImpresionCarnet fase) alDescargarFase;

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
            descargandoPreImpresion: descargandoPreImpresion,
            alDescargarGeneral: () =>
                descargarInformeImpresionCentral(context, central),
            alDescargarPlanilla: () =>
                descargarPlanillaRecoleccionDirectorio(context, central),
            alDescargarPreImpresion: alDescargarPreImpresion,
          ),
          const SizedBox(height: 12),
          _PanelFasesImpresion(
            estado: datos.fases,
            cambiando: cambiandoFase,
            descargando: descargandoFases,
            alHabilitar: alHabilitarFase,
            alCerrar: alCerrarFase,
            alDescargar: alDescargarFase,
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
                etiqueta: 'Pendientes',
                valor: informe.pendientes,
                icono: Icons.pending_actions_outlined,
                color: Colors.amber.shade800,
              ),
              _Cifra(
                etiqueta: 'Sin foto',
                valor: informe.sinFoto,
                icono: Icons.no_photography_outlined,
                color: tema.colorScheme.error,
              ),
              _Cifra(
                etiqueta: 'Observados',
                valor: informe.observados,
                icono: Icons.visibility_outlined,
                color: Colors.orange.shade800,
              ),
              _Cifra(
                etiqueta: 'Sistema',
                valor: informe.sistema,
                icono: Icons.settings_outlined,
                color: Colors.green,
              ),
              _Cifra(
                etiqueta: 'Sin sistema',
                valor: informe.sinSistema,
                icono: Icons.remove_circle_outline,
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
    required this.descargandoPreImpresion,
    required this.alDescargarGeneral,
    required this.alDescargarPlanilla,
    required this.alDescargarPreImpresion,
  });

  final bool descargandoPreImpresion;
  final Future<void> Function() alDescargarGeneral;
  final Future<void> Function() alDescargarPlanilla;
  final Future<void> Function() alDescargarPreImpresion;

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
                  onPressed: descargandoPreImpresion
                      ? null
                      : alDescargarPreImpresion,
                  icon: descargandoPreImpresion
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.rule_folder_outlined),
                  label: const Text('Informe pre-impresión'),
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
            Text('${informe.impresos} de ${informe.total} carnets impresos'),
          ],
        ),
      ),
    );
  }
}

class _PanelFasesImpresion extends StatelessWidget {
  const _PanelFasesImpresion({
    required this.estado,
    required this.cambiando,
    required this.descargando,
    required this.alHabilitar,
    required this.alCerrar,
    required this.alDescargar,
  });

  final EstadoFasesImpresionCentral estado;
  final bool cambiando;
  final Set<int> descargando;
  final Future<void> Function(int numero) alHabilitar;
  final Future<void> Function(FaseImpresionCarnet fase) alCerrar;
  final Future<void> Function(FaseImpresionCarnet fase) alDescargar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final activa = estado.faseActiva;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fases de impresión', style: tema.textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(
              'Windows solo puede imprimir carnets mientras exista una fase '
              'habilitada. Al cerrarla, su informe queda conservado.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (activa == null)
              FilledButton.icon(
                onPressed: cambiando
                    ? null
                    : () => alHabilitar(estado.siguienteNumero),
                icon: cambiando
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_outlined),
                label: Text(
                  'Habilitar ${ordinalFase(estado.siguienteNumero)} fase',
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.print_outlined, color: Colors.orange.shade900),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ordinalFase(activa.numero)} fase de impresión habilitada',
                              style: tema.textTheme.titleSmall?.copyWith(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${activa.impresos} impresos · '
                              '${activa.pendientes} pendientes',
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: cambiando ? null : () => alCerrar(activa),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Cerrar fase'),
                      ),
                    ],
                  ),
                ),
              ),
            if (estado.historial.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Historial e informes', style: tema.textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final fase in estado.historial)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    fase.abierta
                        ? Icons.play_circle_outline
                        : Icons.check_circle_outline,
                    color: fase.abierta ? Colors.orange : Colors.green,
                  ),
                  title: Text('${ordinalFase(fase.numero)} fase'),
                  subtitle: Text(
                    '${fase.impresos} impresos · ${fase.pendientes} pendientes '
                    '· ${fase.abierta ? 'Habilitada' : 'Cerrada'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Descargar informe de la fase',
                    onPressed: descargando.contains(fase.id)
                        ? null
                        : () => alDescargar(fase),
                    icon: descargando.contains(fase.id)
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                  ),
                ),
            ],
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
            Text('${fila.impresos} impresos · ${fila.pendientes} pendientes'),
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
              Text('Pendientes: ${fila.pendientes}'),
              Text('Sin foto: ${fila.sinFoto}'),
              Text('Observados: ${fila.observados}'),
              Text('Sistema: ${fila.sistema}'),
              Text('Sin sistema: ${fila.sinSistema}'),
              Text('Avance: ${_porcentaje(porcentaje)}%'),
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

String _porcentaje(num valor) => valor.toStringAsFixed(1);
