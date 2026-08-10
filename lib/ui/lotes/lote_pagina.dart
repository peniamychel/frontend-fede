import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import '../widgets/ubicacion_pagina.dart';

/// Ficha de una parcela: dónde está, cuánto mide, quién la tiene y su historial.
class LotePagina extends StatefulWidget {
  const LotePagina({super.key, required this.loteId});

  final int loteId;

  @override
  State<LotePagina> createState() => _LotePaginaState();
}

class _LotePaginaState extends State<LotePagina> {
  late Future<_Datos> _futuro;

  /// Queda en true si algo cambió, para que la lista de atrás se recargue.
  bool _huboCambios = false;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    final repo = PadronScope.of(context).lotes;
    setState(() {
      _futuro = _Datos.cargar(repo, widget.loteId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (fueDescartado, _) {
        if (!fueDescartado) Navigator.of(context).pop(_huboCambios);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Parcela'),
          actions: [
            IconButton(
              tooltip: 'Recargar',
              onPressed: _recargar,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: CargaAsync<_Datos>(
          futuro: _futuro,
          alReintentar: _recargar,
          constructor: (context, datos) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Encabezado(
                        lote: datos.lote,
                        alUbicar: () => _ubicar(datos.lote),
                        alMedir: () => _medir(datos.lote),
                        alTraspasar: () => _traspasar(datos.lote),
                        alCambiarSistema: () => _cambiarSistema(datos.lote),
                      ),
                      const SizedBox(height: 20),
                      _Historial(
                        titulo: 'Quiénes la tuvieron',
                        detalle: 'La parcela no se mueve. Lo que cambia es '
                            'quién la tiene, y cada cambio queda registrado.',
                        icono: Icons.history,
                        periodos: datos.tenencias,
                        vacio: 'Todavía no se registró ninguna tenencia.',
                      ),
                      const SizedBox(height: 20),
                      _Historial(
                        titulo: 'Sistemas que pasaron',
                        detalle: 'Un sistema se puede vender y trasladar a otra '
                            'parcela; acá queda por dónde pasó.',
                        icono: Icons.settings_outlined,
                        periodos: datos.sistemas,
                        vacio: 'Nunca tuvo un sistema instalado.',
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Acciones ----------

  Future<void> _ubicar(Lote lote) async {
    final repo = PadronScope.of(context).lotes;
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UbicacionPagina(
          titulo: 'lote ${lote.codigo}',
          subtitulo: 'Sindicato ${lote.sindicatoNombre}',
          queEs: 'la parcela',
          latitud: lote.latitud,
          longitud: lote.longitud,
          ubicacionActualizadaEn: lote.ubicacionActualizadaEn,
          alGuardar: (lat, lon) => repo.marcarUbicacion(lote.id, lat, lon),
          alBorrar: () => repo.borrarUbicacion(lote.id),
        ),
      ),
    );
    if (cambio == true && mounted) {
      _huboCambios = true;
      _recargar();
    }
  }

  /// Vende, hereda o cede la parcela: cambia de manos con fecha y motivo.
  Future<void> _traspasar(Lote lote) async {
    final padron = PadronScope.of(context);

    final List<Productor> candidatos;
    try {
      final pagina = await padron.productores.listar(
        sindicatoId: lote.sindicatoId,
        paginacion: const Paginacion(tamano: 300),
      );
      // Quien ya la tiene no puede recibirla otra vez: el backend lo rechaza y
      // no tiene sentido dejar intentarlo.
      candidatos = pagina.contenido
          .where((p) => p.id != lote.tenedor?.productorId)
          .toList();
    } catch (e) {
      if (mounted) mostrarError(context, e);
      return;
    }
    if (!mounted) return;

    final decision = await showDialog<_Traspaso>(
      context: context,
      builder: (context) => _DialogoTraspaso(lote: lote, candidatos: candidatos),
    );
    if (decision == null || !mounted) return;

    try {
      await padron.lotes.traspasar(
        lote.id,
        TraspasoRequest(
          productorId: decision.productorId,
          motivo: decision.motivo,
          desde: decision.desde,
          observaciones: decision.observaciones,
        ),
      );
      if (!mounted) return;
      _huboCambios = true;
      mostrarExito(
        context,
        decision.productorId == null
            ? 'La parcela quedó sin tenedor'
            : 'Parcela traspasada',
        detalle: decision.productorId == null
            ? 'El período anterior quedó cerrado en el historial.'
            : null,
      );
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  /// Instala un sistema disponible, o retira el que tiene.
  Future<void> _cambiarSistema(Lote lote) async {
    final padron = PadronScope.of(context);

    if (lote.tieneSistema) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Retirar el sistema?'),
          content: Text('${lote.sistema!.codigo} sale de esta parcela y queda '
              'disponible. El período queda cerrado en el historial.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Retirar'),
            ),
          ],
        ),
      );
      if (confirmado != true || !mounted) return;

      try {
        await padron.sistemas.trasladar(lote.sistema!.sistemaId, null,
            const TraspasoRequest(motivo: MotivoTraspaso.otro));
        if (!mounted) return;
        _huboCambios = true;
        _recargar();
      } catch (e) {
        if (mounted) mostrarError(context, e);
      }
      return;
    }

    final List<Sistema> disponibles;
    try {
      disponibles = await padron.sistemas.listar(disponibles: true);
    } catch (e) {
      if (mounted) mostrarError(context, e);
      return;
    }
    if (!mounted) return;

    if (disponibles.isEmpty) {
      mostrarAviso(context, 'No hay sistemas sin instalar',
          detalle: 'Dalos de alta desde la pantalla de sistemas, o retirá uno '
              'de otra parcela.');
      return;
    }

    final elegido = await showDialog<Sistema>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Instalar un sistema'),
        children: [
          for (final s in disponibles)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(s),
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(s.codigo),
                subtitle: s.descripcion == null ? null : Text(s.descripcion!),
              ),
            ),
        ],
      ),
    );
    if (elegido == null || !mounted) return;

    try {
      await padron.sistemas.trasladar(elegido.id, lote.id,
          const TraspasoRequest(motivo: MotivoTraspaso.otro));
      if (!mounted) return;
      _huboCambios = true;
      mostrarExito(context, '${elegido.codigo} instalado');
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _medir(Lote lote) async {
    final hectareas = await showDialog<double?>(
      context: context,
      builder: (context) => _DialogoSuperficie(actual: lote.superficie),
    );
    // null es cancelar; un valor —incluido el que borra la medida— se guarda.
    if (hectareas == null || !mounted) return;

    try {
      await PadronScope.of(context).lotes.actualizar(
            lote.id,
            LoteRequest(
              sindicatoId: lote.sindicatoId,
              numero: lote.numero,
              extension: lote.extension,
              estado: lote.estadoOriginal,
              mercado: lote.mercado?.valor,
              superficie: hectareas < 0 ? null : hectareas,
            ),
          );
      if (!mounted) return;
      _huboCambios = true;
      mostrarExito(context, 'Superficie guardada');
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }
}

/// Las tres consultas de la pantalla, pedidas juntas.
class _Datos {
  const _Datos(this.lote, this.tenencias, this.sistemas);

  final Lote lote;
  final List<Tenencia> tenencias;
  final List<Tenencia> sistemas;

  static Future<_Datos> cargar(LoteRepository repo, int id) async {
    final resultados = await Future.wait([
      repo.obtener(id),
      repo.historial(id),
      repo.historialDeSistemas(id),
    ]);
    return _Datos(
      resultados[0] as Lote,
      resultados[1] as List<Tenencia>,
      resultados[2] as List<Tenencia>,
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.lote,
    required this.alUbicar,
    required this.alMedir,
    required this.alTraspasar,
    required this.alCambiarSistema,
  });

  final Lote lote;
  final VoidCallback alUbicar;
  final VoidCallback alMedir;
  final VoidCallback alTraspasar;
  final VoidCallback alCambiarSistema;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.crop_landscape, color: tema.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Lote ${lote.codigo}', style: tema.textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text('Sindicato ${lote.sindicatoNombre}',
                style: tema.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 28,
              runSpacing: 14,
              children: [
                _Dato(
                  etiqueta: 'Superficie',
                  valor: lote.superficieTexto,
                  atenuado: lote.superficie == null,
                ),
                _Dato(
                  etiqueta: 'Estado',
                  valor: lote.estado.etiqueta,
                  atenuado: lote.necesitaRevision,
                ),
                _Dato(
                  etiqueta: 'Tenedor',
                  valor: lote.tenedor?.nombre ?? 'Sin tenedor',
                  atenuado: !lote.tieneTenedor,
                ),
                _Dato(
                  etiqueta: 'Sistema',
                  valor: lote.sistema?.codigo ?? 'Sin sistema',
                  atenuado: !lote.tieneSistema,
                ),
              ],
            ),
            if (lote.sistemaSinIdentificar) ...[
              const SizedBox(height: 12),
              // La planilla dice que hay sistema pero no cuál. No es un error:
              // es un pendiente de saneamiento, y decirlo evita que parezca
              // una contradicción.
              Row(
                children: [
                  Icon(Icons.help_outline,
                      size: 16, color: tema.colorScheme.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'La planilla dice que tiene sistema, pero todavía no se '
                      'registró cuál.',
                      style: tema.textTheme.bodySmall
                          ?.copyWith(color: tema.colorScheme.outline),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  lote.tieneUbicacion
                      ? Icons.location_on
                      : Icons.location_off_outlined,
                  size: 16,
                  color: lote.tieneUbicacion
                      ? tema.colorScheme.primary
                      : tema.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(lote.coordenadas,
                      style: tema.textTheme.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // El traspaso va primero y destacado: es lo que más se hace
                // con una parcela, porque la tierra se vende y se hereda.
                FilledButton.icon(
                  onPressed: alTraspasar,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(lote.tieneTenedor
                      ? 'Vender o traspasar'
                      : 'Asignar tenedor'),
                ),
                FilledButton.tonalIcon(
                  onPressed: alUbicar,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(lote.tieneUbicacion
                      ? 'Mover en el mapa'
                      : 'Ubicar en el mapa'),
                ),
                OutlinedButton.icon(
                  onPressed: alMedir,
                  icon: const Icon(Icons.straighten, size: 18),
                  label: Text(
                      lote.superficie == null ? 'Poner medida' : 'Cambiar medida'),
                ),
                OutlinedButton.icon(
                  onPressed: alCambiarSistema,
                  icon: Icon(
                      lote.tieneSistema
                          ? Icons.eject_outlined
                          : Icons.settings_outlined,
                      size: 18),
                  label: Text(lote.tieneSistema
                      ? 'Retirar sistema'
                      : 'Instalar sistema'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.etiqueta,
    required this.valor,
    this.atenuado = false,
  });

  final String etiqueta;
  final String valor;
  final bool atenuado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta.toUpperCase(),
            style: tema.textTheme.labelSmall
                ?.copyWith(color: tema.colorScheme.outline)),
        const SizedBox(height: 2),
        Text(valor,
            style: tema.textTheme.titleSmall?.copyWith(
              color: atenuado ? tema.colorScheme.outline : null,
              fontStyle: atenuado ? FontStyle.italic : null,
            )),
      ],
    );
  }
}

/// Un bloque de historial. Sirve para la tenencia y para los sistemas: los dos
/// son la misma lista de períodos con distinto sujeto.
class _Historial extends StatelessWidget {
  const _Historial({
    required this.titulo,
    required this.detalle,
    required this.icono,
    required this.periodos,
    required this.vacio,
  });

  final String titulo;
  final String detalle;
  final IconData icono;
  final List<Tenencia> periodos;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 18, color: tema.colorScheme.outline),
            const SizedBox(width: 8),
            Text(titulo, style: tema.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text(detalle,
            style: tema.textTheme.bodySmall
                ?.copyWith(color: tema.colorScheme.outline)),
        const SizedBox(height: 12),
        if (periodos.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(vacio,
                  style: tema.textTheme.bodyMedium
                      ?.copyWith(color: tema.colorScheme.outline)),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final p in periodos)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      p.vigente ? Icons.person : Icons.person_outline,
                      color: p.vigente
                          ? tema.colorScheme.primary
                          : tema.colorScheme.outline,
                    ),
                    title: Text(
                      p.conQuien,
                      style: TextStyle(
                        color: p.vigente ? null : tema.colorScheme.outline,
                      ),
                    ),
                    subtitle: Text([
                      p.periodo,
                      if (p.motivoEtiqueta != null) p.motivoEtiqueta!,
                      if (p.observaciones != null) p.observaciones!,
                    ].join(' · ')),
                    trailing: p.vigente
                        ? Chip(
                            label: const Text('Actual'),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: tema.colorScheme.primaryContainer,
                          )
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lo que se decidió en el diálogo de traspaso.
class _Traspaso {
  const _Traspaso({
    required this.motivo,
    this.productorId,
    this.desde,
    this.observaciones,
  });

  final MotivoTraspaso motivo;
  final int? productorId;
  final DateTime? desde;
  final String? observaciones;
}

/// Traspasar la parcela: a quién, desde cuándo y por qué.
///
/// El motivo es obligatorio porque es lo que hace legible el historial dentro
/// de un año: «pasó de Ana a Bruno» no dice nada, «se la vendió» sí.
class _DialogoTraspaso extends StatefulWidget {
  const _DialogoTraspaso({required this.lote, required this.candidatos});

  final Lote lote;
  final List<Productor> candidatos;

  @override
  State<_DialogoTraspaso> createState() => _DialogoTraspasoState();
}

class _DialogoTraspasoState extends State<_DialogoTraspaso> {
  final _observaciones = TextEditingController();
  final _busqueda = TextEditingController();

  int? _productorId;
  MotivoTraspaso _motivo = MotivoTraspaso.venta;
  DateTime _desde = DateTime.now();

  /// Deja la parcela sin tenedor: pasa cuando alguien vendió y el comprador
  /// todavía no está cargado en el padrón.
  bool _sinTenedor = false;

  @override
  void dispose() {
    _observaciones.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  List<Productor> get _visibles {
    final filtro = _busqueda.text.trim().toUpperCase();
    if (filtro.isEmpty) return widget.candidatos;
    return widget.candidatos
        .where((p) => p.nombreCompleto.toUpperCase().contains(filtro))
        .toList();
  }

  String get _fechaCorta {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(_desde.day)}/${dos(_desde.month)}/${_desde.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AlertDialog(
      title: Text('Traspasar el lote ${widget.lote.codigo}'),
      content: SizedBox(
        width: 480,
        height: 520,
        child: Column(
          children: [
            if (widget.lote.tieneTenedor)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Hoy la tiene ${widget.lote.tenedor!.nombre}. Su período se '
                  'cierra y queda en el historial.',
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.outline),
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<MotivoTraspaso>(
              initialValue: _motivo,
              decoration: const InputDecoration(
                labelText: 'Motivo *',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final m in MotivoTraspaso.values)
                  DropdownMenuItem(value: m, child: Text(m.etiqueta)),
              ],
              onChanged: (v) => setState(() => _motivo = v ?? _motivo),
            ),
            const SizedBox(height: 12),
            ListTile(
              dense: true,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: tema.colorScheme.outline),
                borderRadius: BorderRadius.circular(4),
              ),
              leading: const Icon(Icons.calendar_today_outlined, size: 20),
              title: const Text('Desde'),
              subtitle: Text(_fechaCorta),
              onTap: _elegirFecha,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: _sinTenedor,
              onChanged: (v) => setState(() {
                _sinTenedor = v ?? false;
                if (_sinTenedor) _productorId = null;
              }),
              title: const Text('Dejarla sin tenedor'),
              subtitle: const Text('El comprador todavía no está en el padrón'),
            ),
            if (!_sinTenedor) ...[
              TextField(
                controller: _busqueda,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Buscar en el sindicato',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: widget.candidatos.isEmpty
                    ? Center(
                        child: Text(
                          'El sindicato no tiene otros productores. Cargá al '
                          'comprador primero, o dejá la parcela sin tenedor.',
                          textAlign: TextAlign.center,
                          style: tema.textTheme.bodySmall
                              ?.copyWith(color: tema.colorScheme.outline),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _visibles.length,
                        itemBuilder: (context, i) {
                          final p = _visibles[i];
                          return RadioListTile<int>(
                            dense: true,
                            value: p.id,
                            // ignore: deprecated_member_use
                            groupValue: _productorId,
                            // ignore: deprecated_member_use
                            onChanged: (v) => setState(() => _productorId = v),
                            title: Text(p.nombreCompleto,
                                overflow: TextOverflow.ellipsis),
                            subtitle: p.ci == null ? null : Text('CI ${p.ci}'),
                          );
                        },
                      ),
              ),
            ] else
              const Spacer(),
            TextField(
              controller: _observaciones,
              decoration: const InputDecoration(
                labelText: 'Observaciones',
                hintText: 'Número de acta, precio, quién intervino',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_sinTenedor || _productorId != null) ? _aceptar : null,
          child: const Text('Traspasar'),
        ),
      ],
    );
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _desde,
      // Cinco años para atrás: los traspasos viejos se cargan tarde, cuando
      // alguien viene a reclamar y hay que dejar constancia de lo que pasó.
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
    );
    if (elegida != null) setState(() => _desde = elegida);
  }

  void _aceptar() {
    final obs = _observaciones.text.trim();
    Navigator.of(context).pop(_Traspaso(
      motivo: _motivo,
      productorId: _sinTenedor ? null : _productorId,
      desde: _desde,
      observaciones: obs.isEmpty ? null : obs,
    ));
  }
}

/// Pide la superficie en hectáreas.
///
/// Devuelve el valor, o -1 para borrar la medida, o null si se canceló. El
/// controlador vive en el State, por lo mismo que en el resto de los diálogos:
/// desecharlo apenas vuelve `showDialog` rompe la aplicación, porque la ruta
/// todavía está animando su salida.
class _DialogoSuperficie extends StatefulWidget {
  const _DialogoSuperficie({this.actual});

  final double? actual;

  @override
  State<_DialogoSuperficie> createState() => _DialogoSuperficieState();
}

class _DialogoSuperficieState extends State<_DialogoSuperficie> {
  late final TextEditingController _controlador = TextEditingController(
    text: widget.actual == null ? '' : '${widget.actual}',
  );
  String? _error;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _aceptar() {
    final texto = _controlador.text.trim().replaceAll(',', '.');
    if (texto.isEmpty) {
      // Vaciar el campo borra la medida: una parcela sin medir es un estado
      // real, distinto de una de cero hectáreas.
      Navigator.of(context).pop(-1.0);
      return;
    }
    final valor = double.tryParse(texto);
    if (valor == null || valor <= 0) {
      setState(() => _error = 'Escribí un número mayor que cero');
      return;
    }
    Navigator.of(context).pop(valor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Superficie de la parcela'),
      content: TextField(
        controller: _controlador,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Hectáreas',
          hintText: '12.5',
          errorText: _error,
          helperText: 'Dejalo vacío para quitar la medida',
        ),
        onSubmitted: (_) => _aceptar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _aceptar, child: const Text('Guardar')),
      ],
    );
  }
}
