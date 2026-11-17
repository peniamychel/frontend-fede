import 'package:flutter/material.dart';

import '../../core/guardar_archivo.dart';
import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../permisos_ui.dart';
import '../widgets/descargar_observaciones_preimpresion_boton.dart';
import '../widgets/estados.dart';
import '../widgets/descargar_productores_excel_boton.dart';
import '../widgets/elegir_orden_informe.dart';

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
  bool _descargandoListaEnBlanco = false;
  bool _configurandoListaEnBlanco = false;
  final Set<int> _descargandoFases = <int>{};
  bool _eligiendoOrden = false;

  Future<OrdenInformes?> _elegirOrden() async {
    if (_eligiendoOrden) return null;
    _eligiendoOrden = true;
    try {
      return await elegirOrdenInforme(context);
    } finally {
      _eligiendoOrden = false;
    }
  }

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
    if (_descargando) return;
    try {
      final orden = await _elegirOrden();
      if (orden == null || !mounted) return;
      setState(() => _descargando = true);
      final archivo = await PadronScope.of(
        context,
      ).sindicatos.descargarRevisionPadron(widget.sindicato.id, orden: orden);
      if (!mounted) return;
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
    if (_descargandoPreImpresion) return;
    try {
      final orden = await _elegirOrden();
      if (orden == null || !mounted) return;
      setState(() => _descargandoPreImpresion = true);
      final archivo = await PadronScope.of(context).sindicatos
          .descargarInformePreImpresion(widget.sindicato.id, orden: orden);
      if (!mounted) return;
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

  Future<void> _descargarListaEnBlanco(int cantidadInicial) async {
    if (_descargandoListaEnBlanco || _configurandoListaEnBlanco) return;
    setState(() => _configurandoListaEnBlanco = true);
    try {
      final filas = await showDialog<int>(
        context: context,
        builder: (_) => _DialogoListaEnBlanco(cantidadInicial: cantidadInicial),
      );
      if (filas == null || !mounted) return;
      setState(() {
        _configurandoListaEnBlanco = false;
        _descargandoListaEnBlanco = true;
      });
      final archivo = await PadronScope.of(
        context,
      ).sindicatos.descargarListaEnBlanco(widget.sindicato.id, filas);
      if (!mounted) return;
      await guardarArchivo(
        archivo.bytes,
        archivo.nombreArchivo,
        archivo.tipoMime,
      );
      if (mounted) mostrarExito(context, 'Lista en blanco descargada.');
    } catch (error) {
      if (mounted) mostrarError(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _descargandoListaEnBlanco = false;
          _configurandoListaEnBlanco = false;
        });
      }
    }
  }

  Future<void> _descargarNomina() async {
    if (_descargandoNomina) return;
    try {
      final orden = await _elegirOrden();
      if (orden == null || !mounted) return;
      setState(() => _descargandoNomina = true);
      final archivo = await PadronScope.of(
        context,
      ).sindicatos.descargarNomina(widget.sindicato.id, orden: orden);
      if (!mounted) return;
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
    if (_descargandoFases.contains(fase.id)) return;
    try {
      final orden = await _elegirOrden();
      if (orden == null || !mounted) return;
      setState(() => _descargandoFases.add(fase.id));
      final archivo = await PadronScope.of(context).sindicatos
          .descargarInformeFase(widget.sindicato.id, fase.id, orden: orden);
      if (!mounted) return;
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
                    DescargarProductoresExcelBoton.sindicato(
                      id: widget.sindicato.id,
                    ),
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
                    DescargarObservacionesPreimpresionBoton.sindicato(
                      id: widget.sindicato.id,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed:
                          _descargandoListaEnBlanco ||
                              _configurandoListaEnBlanco
                          ? null
                          : () => _descargarListaEnBlanco(avance.total),
                      icon: _descargandoListaEnBlanco
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.table_rows_outlined),
                      label: const Text('Lista en blanco'),
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

class _DialogoListaEnBlanco extends StatefulWidget {
  const _DialogoListaEnBlanco({required this.cantidadInicial});
  final int cantidadInicial;

  @override
  State<_DialogoListaEnBlanco> createState() => _DialogoListaEnBlancoState();
}

class _DialogoListaEnBlancoState extends State<_DialogoListaEnBlanco> {
  final _formulario = GlobalKey<FormState>();
  late final _cantidad = TextEditingController(
    text: widget.cantidadInicial > 0 ? '${widget.cantidadInicial}' : '',
  );

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  void _generar() {
    if (!_formulario.currentState!.validate()) return;
    Navigator.of(context).pop(int.parse(_cantidad.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Generar lista en blanco'),
    content: SizedBox(
      width: 380,
      child: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Se generará una fila vacía por afiliado.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cantidad,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Cantidad de afiliados',
              ),
              validator: (valor) {
                final cantidad = int.tryParse(valor?.trim() ?? '');
                return cantidad == null || cantidad < 1 || cantidad > 5000
                    ? 'Ingresá un número entre 1 y 5000.'
                    : null;
              },
              onFieldSubmitted: (_) => _generar(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _generar, child: const Text('Generar PDF')),
    ],
  );
}

class _DatosSindicato {
  const _DatosSindicato({required this.avance, required this.fases});

  final AvanceImpresionSindicato avance;
  final List<FaseInformeSindicato> fases;
}
