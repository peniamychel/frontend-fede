import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';

/// Reconciliación de la lista completa de productores con SISTEMA de UDESTRO.
/// Las decisiones se guardan en un borrador del backend y solo el botón final
/// modifica el padrón.
class ConciliacionUdestroPagina extends StatefulWidget {
  const ConciliacionUdestroPagina({super.key});

  @override
  State<ConciliacionUdestroPagina> createState() =>
      _ConciliacionUdestroPaginaState();
}

class _ConciliacionUdestroPaginaState extends State<ConciliacionUdestroPagina> {
  PlatformFile? _archivo;
  ConciliacionUdestro? _resumen;
  Pagina<FilaConciliacionUdestro> _filas = Pagina.vacia();
  AccionConciliacionUdestro _filtro =
      AccionConciliacionUdestro.conflictoIdentidad;
  bool _trabajando = false;
  bool _cargandoFilas = false;
  bool _aprobarSindicatos = false;
  final Set<int> _decidiendo = {};

  @override
  Widget build(BuildContext context) {
    final resumen = _resumen;
    return Scaffold(
      appBar: AppBar(title: const Text('Conciliar UDESTRO')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _explicacion(context),
                  const SizedBox(height: 16),
                  _selector(context),
                  if (resumen != null) ...[
                    const SizedBox(height: 16),
                    _resumenCard(context, resumen),
                    const SizedBox(height: 16),
                    _detalle(context, resumen),
                    const SizedBox(height: 16),
                    _aplicacion(context, resumen),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _explicacion(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      color: tema.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lista completa de productores con SISTEMA',
              style: tema.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'El análisis no cambia el padrón. Quienes estén en UDESTRO se '
              'proponen como SISTEMA; quienes no estén y actualmente sean '
              'SISTEMA, SIN SISTEMA o no tengan clasificación se proponen como '
              'BLANCO. Las demás clasificaciones se conservan.',
            ),
            const SizedBox(height: 8),
            const Text(
              'La revisión SIE no se modifica. Los productores nuevos quedarán '
              'sin lote, con SISTEMA pendiente y serán revisados por SIE al '
              'abrir su ficha.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando la CI ya existe, se conserva la identidad actual con 50% '
              'o más de similitud. Por debajo de 50% también pasa a SISTEMA, '
              'pero queda Observado con el nombre informado por UDESTRO.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _selector(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('1. Cargar y analizar', style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            InkWell(
              onTap: _trabajando ? null : _elegirArchivo,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _archivo == null
                        ? tema.colorScheme.outlineVariant
                        : tema.colorScheme.primary,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.upload_file_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _archivo == null
                            ? 'Elegir planilla UDESTRO .xlsx'
                            : '${_archivo!.name} · '
                                  '${(_archivo!.size / 1024).toStringAsFixed(1)} KB',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_archivo != null) const Text('Cambiar'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _archivo == null || _trabajando ? null : _analizar,
              icon: _trabajando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: Text(
                _resumen == null
                    ? 'Analizar sin aplicar'
                    : 'Crear nuevo análisis',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _trabajando ? null : _continuarBorrador,
              icon: const Icon(Icons.restore),
              label: const Text('Continuar último borrador'),
            ),
            const SizedBox(height: 6),
            Text(
              'Destino fijo: CARRASCO TROPICAL.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumenCard(BuildContext context, ConciliacionUdestro r) {
    final tema = Theme.of(context);
    final aplicado = r.estado == EstadoConciliacionUdestro.aplicada;
    final valores = <(String, int, IconData, bool)>[
      ('Filas del Excel', r.filasExcel, Icons.table_rows_outlined, false),
      ('Altas SISTEMA', r.altasSistema, Icons.person_add_alt, false),
      ('Cambios a SISTEMA', r.cambiosASistema, Icons.settings_outlined, false),
      (
        'Observados por identidad',
        r.observadosPorIdentidad,
        Icons.person_off_outlined,
        r.observadosPorIdentidad > 0,
      ),
      ('Cambios a BLANCO', r.cambiosABlanco, Icons.circle_outlined, false),
      ('Se conservan', r.conservados, Icons.lock_outline, false),
      (
        'Conflictos pendientes',
        r.conflictosPendientes,
        Icons.compare_arrows_outlined,
        r.conflictosPendientes > 0,
      ),
      ('Errores', r.errores, Icons.error_outline, r.errores > 0),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  aplicado ? Icons.check_circle : Icons.visibility_outlined,
                  color: aplicado ? tema.colorScheme.primary : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    aplicado ? 'Conciliación aplicada' : 'Propuesta guardada',
                    style: tema.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${r.archivo} · ${r.federacion}',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in valores)
                  _ResumenDato(
                    etiqueta: v.$1,
                    valor: v.$2,
                    icono: v.$3,
                    alerta: v.$4,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detalle(BuildContext context, ConciliacionUdestro resumen) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('2. Revisar la propuesta', style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccionConciliacionUdestro>(
              initialValue: _filtro,
              decoration: const InputDecoration(labelText: 'Mostrar'),
              items: [
                for (final accion in AccionConciliacionUdestro.values)
                  DropdownMenuItem(
                    value: accion,
                    child: Text(
                      '${accion.etiqueta} (${_cantidad(resumen, accion)})',
                    ),
                  ),
              ],
              onChanged: _cargandoFilas
                  ? null
                  : (accion) {
                      if (accion != null) _cargarFilas(accion, pagina: 0);
                    },
            ),
            const SizedBox(height: 14),
            if (_cargandoFilas)
              const Center(child: CircularProgressIndicator())
            else if (_filas.contenido.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay registros en esta categoría.',
                  textAlign: TextAlign.center,
                ),
              )
            else ...[
              for (final fila in _filas.contenido) ...[
                _fila(context, fila),
                const SizedBox(height: 8),
              ],
              _paginacion(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fila(BuildContext context, FilaConciliacionUdestro fila) {
    final tema = Theme.of(context);
    final conflicto =
        fila.accion == AccionConciliacionUdestro.conflictoIdentidad;
    final error = fila.accion == AccionConciliacionUdestro.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error
              ? tema.colorScheme.error
              : conflicto
              ? tema.colorScheme.tertiary
              : tema.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                error
                    ? Icons.error_outline
                    : conflicto
                    ? Icons.compare_arrows_outlined
                    : _icono(fila.accion),
                color: error
                    ? tema.colorScheme.error
                    : conflicto
                    ? tema.colorScheme.tertiary
                    : tema.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fila.nombreCompleto.isEmpty
                          ? 'Registro actual ID ${fila.productorId ?? '-'}'
                          : fila.nombreCompleto,
                      style: tema.textTheme.titleSmall,
                    ),
                    Text(
                      'CI ${fila.ci.isEmpty ? 'sin dato' : fila.ci} · '
                      '${fila.central} › ${fila.sindicato}'
                      '${fila.numeroFila == null ? '' : ' · fila ${fila.numeroFila}'}',
                      style: tema.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(_etiquetaAccion(fila.accion)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(fila.motivo),
          if (fila.similitudNombre != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: const Icon(Icons.percent, size: 16),
                  label: Text('${fila.similitudNombre}% de similitud'),
                  visualDensity: VisualDensity.compact,
                ),
                if (fila.candidatos.length == 1)
                  Text(
                    'Actual: ${fila.candidatos.single.nombreCompleto}',
                    style: tema.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
          if (fila.sindicatoNuevo) ...[
            const SizedBox(height: 6),
            const Text(
              'Este sindicato todavía no existe y requiere aprobación.',
            ),
          ],
          if (conflicto) ...[
            const SizedBox(height: 12),
            Text(
              'Datos actuales con la misma CI',
              style: tema.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            for (final candidato in fila.candidatos) ...[
              _candidato(context, fila, candidato),
              const SizedBox(height: 8),
            ],
            if (fila.decision != DecisionConflictoUdestro.pendiente)
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 18,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fila.decision == DecisionConflictoUdestro.mismaPersona
                          ? 'Decisión guardada: es la misma persona.'
                          : 'Decisión guardada: se creará la persona de UDESTRO '
                                'y se observará el registro seleccionado.',
                    ),
                  ),
                  TextButton(
                    onPressed: _decidiendo.contains(fila.id)
                        ? null
                        : () => _decidir(
                            fila,
                            DecisionConflictoUdestro.pendiente,
                            null,
                          ),
                    child: const Text('Cambiar'),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _candidato(
    BuildContext context,
    FilaConciliacionUdestro fila,
    CandidatoUdestro candidato,
  ) {
    final tema = Theme.of(context);
    final seleccionado = fila.productorSeleccionadoId == candidato.id;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: seleccionado ? tema.colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (candidato.fotoUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ApiConfig.urlAbsoluta(candidato.fotoUrl!),
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.square(
                      dimension: 58,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidato.nombreCompleto,
                      style: tema.textTheme.titleSmall,
                    ),
                    Text(
                      '${candidato.central} › ${candidato.sindicato}\n'
                      '${candidato.clasificacion?.etiqueta ?? 'Sin clasificación'} '
                      '· ID ${candidato.id}',
                      style: tema.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _decidiendo.contains(fila.id)
                    ? null
                    : () => _confirmarDecision(
                        fila,
                        candidato,
                        DecisionConflictoUdestro.mismaPersona,
                      ),
                icon: const Icon(Icons.person_outline),
                label: const Text('Es la misma persona'),
              ),
              OutlinedButton.icon(
                onPressed: _decidiendo.contains(fila.id)
                    ? null
                    : () => _confirmarDecision(
                        fila,
                        candidato,
                        DecisionConflictoUdestro.personasDistintas,
                      ),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Son personas distintas'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paginacion(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'Página anterior',
        onPressed: _filas.numero > 0
            ? () => _cargarFilas(_filtro, pagina: _filas.numero - 1)
            : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text('Página ${_filas.numero + 1} de ${_filas.totalPaginas}'),
      IconButton(
        tooltip: 'Página siguiente',
        onPressed: _filas.hayMas
            ? () => _cargarFilas(_filtro, pagina: _filas.numero + 1)
            : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  Widget _aplicacion(BuildContext context, ConciliacionUdestro resumen) {
    final tema = Theme.of(context);
    if (resumen.estado == EstadoConciliacionUdestro.aplicada) {
      return Card(
        color: tema.colorScheme.primaryContainer,
        child: const Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'La conciliación ya fue aplicada. No puede ejecutarse nuevamente.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final sindicatosListos =
        resumen.sindicatosNuevos.isEmpty || _aprobarSindicatos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('3. Aplicar conciliación', style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (resumen.sindicatosNuevos.isNotEmpty) ...[
              Text('Sindicatos nuevos (${resumen.sindicatosNuevos.length})'),
              const SizedBox(height: 6),
              for (final sindicato in resumen.sindicatosNuevos)
                Text('• ${sindicato.central} › ${sindicato.sindicato}'),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _aprobarSindicatos,
                onChanged: _trabajando
                    ? null
                    : (v) => setState(() => _aprobarSindicatos = v ?? false),
                title: const Text('Aprobar la creación de estos sindicatos'),
              ),
            ],
            if (resumen.conflictosPendientes > 0)
              Text(
                'Falta resolver ${resumen.conflictosPendientes} conflicto(s).',
                style: TextStyle(color: tema.colorScheme.error),
              ),
            if (resumen.errores > 0)
              Text(
                'Hay ${resumen.errores} error(es). Corregí la planilla o los '
                'datos indicados y creá un análisis nuevo.',
                style: TextStyle(color: tema.colorScheme.error),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  resumen.listaParaAplicar && sindicatosListos && !_trabajando
                  ? _confirmarAplicacion
                  : null,
              icon: _trabajando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all),
              label: const Text('Aplicar conciliación'),
            ),
            const SizedBox(height: 6),
            Text(
              'Solo este botón modifica productores, clasificaciones y '
              'observaciones. El servidor volverá a validar que el padrón no '
              'haya cambiado desde el análisis.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _elegirArchivo() async {
    try {
      final resultado = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );
      final archivo = resultado?.files.firstOrNull;
      if (archivo == null || !mounted) return;
      setState(() {
        _archivo = archivo;
        _resumen = null;
        _filas = Pagina.vacia();
        _aprobarSindicatos = false;
      });
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _analizar() async {
    final archivo = _archivo;
    if (archivo?.bytes == null) {
      mostrarAviso(context, 'No se pudo leer el archivo. Elegilo nuevamente.');
      return;
    }
    setState(() => _trabajando = true);
    try {
      final resumen = await PadronScope.of(context).importaciones
          .analizarUdestro(bytes: archivo!.bytes!, nombreArchivo: archivo.name);
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _trabajando = false;
        _aprobarSindicatos = false;
      });
      final filtro = resumen.conflictos > 0
          ? AccionConciliacionUdestro.conflictoIdentidad
          : resumen.errores > 0
          ? AccionConciliacionUdestro.error
          : resumen.observadosPorIdentidad > 0
          ? AccionConciliacionUdestro.observarYCambiarASistema
          : AccionConciliacionUdestro.cambiarASistema;
      await _cargarFilas(filtro, pagina: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _trabajando = false);
      mostrarError(context, e);
    }
  }

  Future<void> _continuarBorrador() async {
    setState(() => _trabajando = true);
    try {
      final resumen = await PadronScope.of(
        context,
      ).importaciones.ultimoBorradorUdestro();
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _archivo = null;
        _trabajando = false;
        _aprobarSindicatos = false;
      });
      final filtro = resumen.conflictos > 0
          ? AccionConciliacionUdestro.conflictoIdentidad
          : resumen.errores > 0
          ? AccionConciliacionUdestro.error
          : resumen.observadosPorIdentidad > 0
          ? AccionConciliacionUdestro.observarYCambiarASistema
          : AccionConciliacionUdestro.cambiarASistema;
      await _cargarFilas(filtro, pagina: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _trabajando = false);
      mostrarError(context, e);
    }
  }

  Future<void> _cargarFilas(
    AccionConciliacionUdestro accion, {
    required int pagina,
  }) async {
    final id = _resumen?.id;
    if (id == null) return;
    setState(() {
      _filtro = accion;
      _cargandoFilas = true;
    });
    try {
      final filas = await PadronScope.of(
        context,
      ).importaciones.filasUdestro(id, accion: accion, pagina: pagina);
      if (!mounted) return;
      setState(() {
        _filas = filas;
        _cargandoFilas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoFilas = false);
      mostrarError(context, e);
    }
  }

  Future<void> _confirmarDecision(
    FilaConciliacionUdestro fila,
    CandidatoUdestro candidato,
    DecisionConflictoUdestro decision,
  ) async {
    final distintas = decision == DecisionConflictoUdestro.personasDistintas;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          distintas ? '¿Son personas distintas?' : '¿Es la misma persona?',
        ),
        content: Text(
          distintas
              ? 'Se creará ${fila.nombreCompleto} como productor nuevo con '
                    'SISTEMA. ${candidato.nombreCompleto} conservará sus datos, '
                    'foto, lote e historial, pero quedará Observado y no podrá imprimir.'
              : '${candidato.nombreCompleto} se conservará como el mismo '
                    'productor y pasará a SISTEMA. Su nombre y ubicación actual '
                    'no serán reemplazados automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar decisión'),
          ),
        ],
      ),
    );
    if (confirmar == true) await _decidir(fila, decision, candidato.id);
  }

  Future<void> _decidir(
    FilaConciliacionUdestro fila,
    DecisionConflictoUdestro decision,
    int? productorId,
  ) async {
    final id = _resumen!.id;
    final repositorio = PadronScope.of(context).importaciones;
    setState(() => _decidiendo.add(fila.id));
    try {
      final actualizada = await repositorio.decidirConflictoUdestro(
        conciliacionId: id,
        filaId: fila.id,
        decision: decision,
        productorId: productorId,
      );
      final resumen = await repositorio.obtenerConciliacionUdestro(id);
      if (!mounted) return;
      setState(() {
        _filas = Pagina(
          contenido: [
            for (final f in _filas.contenido)
              if (f.id == actualizada.id) actualizada else f,
          ],
          tamano: _filas.tamano,
          numero: _filas.numero,
          totalElementos: _filas.totalElementos,
          totalPaginas: _filas.totalPaginas,
        );
        _resumen = resumen;
        _decidiendo.remove(fila.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _decidiendo.remove(fila.id));
      mostrarError(context, e);
    }
  }

  Future<void> _confirmarAplicacion() async {
    final resumen = _resumen!;
    final repositorio = PadronScope.of(context).importaciones;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Aplicar conciliación UDESTRO?'),
        content: Text(
          'Se crearán ${resumen.altasSistema} productores, '
          '${resumen.cambiosASistema} pasarán a SISTEMA y '
          '${resumen.observadosPorIdentidad} pasarán a SISTEMA como Observados; '
          '${resumen.cambiosABlanco} pasarán a BLANCO. Esta acción modifica '
          'el padrón y no se puede ejecutar dos veces.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aplicar conciliación'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    if (!mounted) return;
    setState(() => _trabajando = true);
    try {
      final aplicada = await repositorio.aplicarUdestro(
        resumen.id,
        aprobarSindicatosNuevos: _aprobarSindicatos,
      );
      if (!mounted) return;
      setState(() {
        _resumen = aplicada;
        _trabajando = false;
      });
      mostrarExito(
        context,
        'Conciliación aplicada',
        detalle: '${aplicada.cambiosTotales} cambios procesados.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _trabajando = false);
      mostrarError(context, e);
    }
  }

  int _cantidad(ConciliacionUdestro r, AccionConciliacionUdestro accion) =>
      switch (accion) {
        AccionConciliacionUdestro.altaSistema => r.altasSistema,
        AccionConciliacionUdestro.cambiarASistema => r.cambiosASistema,
        AccionConciliacionUdestro.observarYCambiarASistema =>
          r.observadosPorIdentidad,
        AccionConciliacionUdestro.cambiarABlanco => r.cambiosABlanco,
        AccionConciliacionUdestro.conservar => r.conservados,
        AccionConciliacionUdestro.conflictoIdentidad => r.conflictos,
        AccionConciliacionUdestro.error => r.errores,
      };

  IconData _icono(AccionConciliacionUdestro accion) => switch (accion) {
    AccionConciliacionUdestro.altaSistema => Icons.person_add_alt,
    AccionConciliacionUdestro.cambiarASistema => Icons.settings_outlined,
    AccionConciliacionUdestro.observarYCambiarASistema =>
      Icons.person_off_outlined,
    AccionConciliacionUdestro.cambiarABlanco => Icons.circle_outlined,
    AccionConciliacionUdestro.conservar => Icons.lock_outline,
    AccionConciliacionUdestro.conflictoIdentidad => Icons.compare_arrows,
    AccionConciliacionUdestro.error => Icons.error_outline,
  };

  String _etiquetaAccion(AccionConciliacionUdestro accion) => switch (accion) {
    AccionConciliacionUdestro.altaSistema => 'Alta SISTEMA',
    AccionConciliacionUdestro.cambiarASistema => 'A SISTEMA',
    AccionConciliacionUdestro.observarYCambiarASistema => 'SISTEMA · Observado',
    AccionConciliacionUdestro.cambiarABlanco => 'A BLANCO',
    AccionConciliacionUdestro.conservar => 'Conservar',
    AccionConciliacionUdestro.conflictoIdentidad => 'Revisar',
    AccionConciliacionUdestro.error => 'Error',
  };
}

class _ResumenDato extends StatelessWidget {
  const _ResumenDato({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    required this.alerta,
  });

  final String etiqueta;
  final int valor;
  final IconData icono;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = alerta ? tema.colorScheme.error : tema.colorScheme.primary;
    return Container(
      width: 205,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tema.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icono, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(etiqueta, style: tema.textTheme.labelMedium)),
          Text(
            '$valor',
            style: tema.textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
