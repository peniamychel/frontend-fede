import 'package:flutter/material.dart';

import '../../core/guardar_archivo.dart';
import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../permisos_ui.dart';
import '../widgets/estados.dart';

/// Resumen y descarga del informe de revisión de un solo sindicato.
class InformeImpresionSindicatoPagina extends StatefulWidget {
  const InformeImpresionSindicatoPagina({super.key, required this.sindicato});

  final Sindicato sindicato;

  @override
  State<InformeImpresionSindicatoPagina> createState() =>
      _InformeImpresionSindicatoPaginaState();
}

class _InformeImpresionSindicatoPaginaState
    extends State<InformeImpresionSindicatoPagina> {
  late Future<_DatosSindicato> _futuro;
  bool _descargando = false;
  bool _descargandoPreImpresion = false;
  bool _descargandoNomina = false;
  final Set<int> _descargandoFases = <int>{};

  @override
  void initState() {
    super.initState();
    _futuro = _cargar();
  }

  Future<_DatosSindicato> _cargar() async {
    final repositorio = PadronScope.of(context).sindicatos;
    final avance = await repositorio.avanceImpresion(widget.sindicato.id);
    final fases = await repositorio.fasesInforme(widget.sindicato.id);
    return _DatosSindicato(avance: avance, fases: fases);
  }

  Future<void> _recargar() async {
    final futuro = _cargar();
    setState(() => _futuro = futuro);
    await futuro;
  }

  Future<void> _descargar() async {
    setState(() => _descargando = true);
    try {
      final archivo = await PadronScope.of(
        context,
      ).sindicatos.descargarRevisionPadron(widget.sindicato.id);
      await guardarArchivo(
        archivo.bytes,
        archivo.nombreArchivo,
        archivo.tipoMime,
      );
      if (mounted) mostrarExito(context, 'Informe del sindicato descargado.');
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  Future<void> _descargarPreImpresion() async {
    setState(() => _descargandoPreImpresion = true);
    try {
      final archivo = await PadronScope.of(
        context,
      ).sindicatos.descargarInformePreImpresion(widget.sindicato.id);
      await guardarArchivo(
        archivo.bytes,
        archivo.nombreArchivo,
        archivo.tipoMime,
      );
      if (mounted) mostrarExito(context, 'Informe pre-impresión descargado.');
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _descargandoPreImpresion = false);
    }
  }

  Future<void> _descargarNomina() async {
    setState(() => _descargandoNomina = true);
    try {
      final archivo = await PadronScope.of(
        context,
      ).sindicatos.descargarNomina(widget.sindicato.id);
      await guardarArchivo(
        archivo.bytes,
        archivo.nombreArchivo,
        archivo.tipoMime,
      );
      if (mounted) mostrarExito(context, 'Nómina del sindicato descargada.');
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _descargandoNomina = false);
    }
  }

  Future<void> _descargarFase(FaseInformeSindicato fase) async {
    setState(() => _descargandoFases.add(fase.id));
    try {
      final archivo = await PadronScope.of(
        context,
      ).sindicatos.descargarInformeFase(widget.sindicato.id, fase.id);
      await guardarArchivo(
        archivo.bytes,
        archivo.nombreArchivo,
        archivo.tipoMime,
      );
      if (mounted) {
        mostrarExito(context, 'Informe de la fase ${fase.numero} descargado.');
      }
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) setState(() => _descargandoFases.remove(fase.id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Informes y reportes del sindicato'),
      actions: [
        IconButton(
          tooltip: 'Recargar',
          onPressed: _recargar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: CargaAsync<_DatosSindicato>(
      futuro: _futuro,
      alReintentar: _recargar,
      constructor: (context, datos) =>
          _contenido(context, datos.avance, datos.fases),
    ),
  );

  Widget _contenido(
    BuildContext context,
    AvanceImpresionSindicato avance,
    List<FaseInformeSindicato> fases,
  ) {
    final tema = Theme.of(context);
    final porcentaje = avance.porcentajeAvance.clamp(0, 100);
    return RefreshIndicator(
      onRefresh: _recargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            avance.sindicato,
            style: tema.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text('Central ${widget.sindicato.centralNombre}'),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Avance de impresión')),
                      Text(
                        '${porcentaje.toStringAsFixed(1)}%',
                        style: tema.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                    '${avance.impresos} de ${avance.total} carnets impresos',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (context.puede('INFORMES_DESCARGAR'))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Generar informes', style: tema.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: _descargando ? null : _descargar,
                      icon: _descargando
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fact_check_outlined),
                      label: const Text('Informe de revisión del padrón'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: _descargandoPreImpresion
                          ? null
                          : _descargarPreImpresion,
                      icon: _descargandoPreImpresion
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.description_outlined),
                      label: const Text('Informe pre-impresión'),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: _descargandoNomina ? null : _descargarNomina,
                      icon: _descargandoNomina
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Nómina en PDF'),
                    ),
                    if (fases.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Informes por fase de impresión',
                        style: tema.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      for (final fase in fases)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            fase.abierta
                                ? Icons.play_circle_outline
                                : Icons.check_circle_outline,
                          ),
                          title: Text('Fase ${fase.numero}'),
                          subtitle: Text(
                            fase.abierta ? 'Habilitada' : 'Cerrada',
                          ),
                          trailing: IconButton(
                            tooltip: 'Descargar informe de esta fase',
                            onPressed: _descargandoFases.contains(fase.id)
                                ? null
                                : () => _descargarFase(fase),
                            icon: _descargandoFases.contains(fase.id)
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.picture_as_pdf_outlined),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _cifra('Total', avance.total, Icons.badge_outlined),
              _cifra('Impresos', avance.impresos, Icons.print_outlined),
              _cifra('Pendientes', avance.pendientes, Icons.pending_outlined),
              _cifra('Sin foto', avance.sinFoto, Icons.no_photography_outlined),
              _cifra(
                'Observados',
                avance.observados,
                Icons.visibility_outlined,
              ),
              _cifra('Sistema', avance.sistema, Icons.settings_outlined),
              _cifra(
                'Sin sistema',
                avance.sinSistema,
                Icons.remove_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(
              avance.selloCargado
                  ? Icons.verified_outlined
                  : Icons.warning_amber_outlined,
            ),
            title: Text(
              avance.selloCargado
                  ? 'Sello del sindicato cargado'
                  : 'Sello del sindicato pendiente',
            ),
          ),
        ],
      ),
    );
  }

  Widget _cifra(String titulo, int valor, IconData icono) => SizedBox(
    width: 160,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, size: 20),
            const SizedBox(height: 6),
            Text('$valor', style: Theme.of(context).textTheme.titleLarge),
            Text(titulo),
          ],
        ),
      ),
    ),
  );
}

class _DatosSindicato {
  const _DatosSindicato({required this.avance, required this.fases});

  final AvanceImpresionSindicato avance;
  final List<FaseInformeSindicato> fases;
}
