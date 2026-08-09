import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/productor_detalle_pagina.dart';
import '../widgets/descargas.dart';
import '../widgets/estados.dart';
import 'firmas_cargo.dart';

/// Directorio de un sindicato, una central o la federación.
///
/// La misma pantalla sirve para los tres: el backend devuelve un puesto por
/// cada cargo que admite el nivel, así que acá no hay ninguna lista de cargos
/// escrita a mano. Si mañana la federación suma uno, aparece sin tocar esto.
class DirectorioPagina extends StatefulWidget {
  const DirectorioPagina({
    super.key,
    required this.ambito,
    required this.id,
    required this.nombre,
    this.subtitulo,
  });

  /// Directorio de un sindicato, con la central como subtítulo.
  DirectorioPagina.deSindicato(Sindicato sindicato, {super.key})
      : ambito = Ambito.sindicato,
        id = sindicato.id,
        nombre = sindicato.nombre,
        subtitulo = 'Central ${sindicato.centralNombre}';

  DirectorioPagina.deCentral(Central central, {super.key})
      : ambito = Ambito.central,
        id = central.id,
        nombre = central.nombre,
        subtitulo = 'Federación ${central.federacionNombre}';

  DirectorioPagina.deFederacion(Federacion federacion, {super.key})
      : ambito = Ambito.federacion,
        id = federacion.id,
        nombre = federacion.nombre,
        subtitulo = null;

  final Ambito ambito;
  final int id;
  final String nombre;
  final String? subtitulo;

  @override
  State<DirectorioPagina> createState() => _DirectorioPaginaState();
}

class _DirectorioPaginaState extends State<DirectorioPagina> {
  late Future<_Datos> _futuro;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    final repo = PadronScope.of(context).directorios;
    setState(() {
      _futuro = _Datos.cargar(repo, widget.ambito, widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Directorio de ${widget.nombre}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              widget.subtitulo ?? widget.ambito.etiqueta,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _puestos(context, datos.directorio),
                    const SizedBox(height: 24),
                    _historial(context, datos.historial),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Las tarjetas, en tantas columnas como entren.
  ///
  /// Se usa un Wrap y no una fila fija porque la cantidad de cargos cambia con
  /// el nivel: dos en un sindicato, cuatro en la federación.
  Widget _puestos(BuildContext context, Directorio directorio) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        const separacion = 12.0;
        final columnas = restricciones.maxWidth < 620 ? 1 : 2;
        final ancho = columnas == 1
            ? restricciones.maxWidth
            : (restricciones.maxWidth - separacion) / 2;

        return Wrap(
          spacing: separacion,
          runSpacing: separacion,
          children: [
            for (final puesto in directorio.puestos)
              SizedBox(
                width: ancho,
                child: _TarjetaCargo(
                  puesto: puesto,
                  ocupado: _ocupado,
                  alAsignar: () => _asignar(puesto),
                  alTerminar: () => _terminar(puesto),
                  alAbrirProductor: _abrirProductor,
                  alCambiarFirmas: _recargar,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _historial(BuildContext context, List<Cargo> historial) {
    final tema = Theme.of(context);
    final pasados = historial.where((c) => !c.vigente).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 18, color: tema.colorScheme.outline),
            const SizedBox(width: 8),
            Text('Historial', style: tema.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Cada cambio queda registrado. Nadie se borra al ser reemplazado.',
          style: tema.textTheme.bodySmall
              ?.copyWith(color: tema.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        if (historial.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Todavía no se registró ningún cargo acá.',
                style: tema.textTheme.bodyMedium
                    ?.copyWith(color: tema.colorScheme.outline),
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final c in historial)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      _icono(c.cargo),
                      color: c.vigente
                          ? tema.colorScheme.primary
                          : tema.colorScheme.outline,
                    ),
                    title: Text(
                      c.productorNombre,
                      style: TextStyle(
                        color: c.vigente ? null : tema.colorScheme.outline,
                      ),
                    ),
                    subtitle: Text('${c.cargo.etiqueta} · ${c.periodo}'),
                    trailing: c.vigente
                        ? Chip(
                            label: const Text('En funciones'),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: tema.colorScheme.primaryContainer,
                          )
                        : null,
                    onTap: () => _abrirProductor(c.productorId),
                  ),
              ],
            ),
          ),
        if (pasados.isEmpty && historial.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Todavía no hubo relevos.',
            style: tema.textTheme.bodySmall
                ?.copyWith(color: tema.colorScheme.outline),
          ),
        ],
      ],
    );
  }

  // ---------- Acciones ----------

  Future<void> _asignar(Puesto puesto) async {
    final padron = PadronScope.of(context);
    final actual = puesto.actual;

    // La lista la arma el backend: son los del nivel, sin los que ya ocupan
    // otro cargo ni los deshabilitados. Duplicar esa regla acá sería pedir que
    // las dos versiones no se separen nunca.
    final List<Productor> candidatos;
    try {
      candidatos = await padron.directorios.candidatos(widget.ambito, widget.id);
    } catch (e) {
      if (mounted) mostrarError(context, e);
      return;
    }
    if (!mounted) return;

    if (candidatos.isEmpty) {
      mostrarAviso(context, 'No hay productores disponibles',
          detalle: 'El directorio se elige entre los productores de '
              '${widget.nombre}, y los que ya ocupan un cargo no cuentan.');
      return;
    }

    final elegido = await showDialog<Productor>(
      context: context,
      builder: (context) => _SelectorProductor(
        puesto: puesto,
        candidatos: candidatos,
        ambito: widget.ambito,
      ),
    );
    if (elegido == null || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await padron.directorios.asignar(
        ambito: widget.ambito,
        id: widget.id,
        cargo: puesto.cargo,
        productorId: elegido.id,
      );
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarExito(context, '${puesto.etiqueta} asignado',
          detalle: actual == null
              ? elegido.nombreCompleto
              : '${elegido.nombreCompleto} reemplaza a '
                  '${actual.productorNombre}.');
      _recargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarError(context, e);
    }
  }

  Future<void> _terminar(Puesto puesto) async {
    final actual = puesto.actual;
    if (actual == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Dejar vacante ${puesto.etiqueta.toLowerCase()}?'),
        content: Text(
          '${actual.productorNombre} deja el cargo y no se nombra reemplazo. '
          'El período queda cerrado en el historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Dejar vacante'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      await PadronScope.of(context).directorios.terminar(
            ambito: widget.ambito,
            id: widget.id,
            cargo: puesto.cargo,
          );
      if (!mounted) return;
      setState(() => _ocupado = false);
      _recargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      mostrarError(context, e);
    }
  }

  Future<void> _abrirProductor(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductorDetallePagina(productorId: id)),
    );
    if (mounted) _recargar();
  }
}

IconData _icono(TipoCargo cargo) => switch (cargo) {
      TipoCargo.presidente => Icons.workspace_premium_outlined,
      TipoCargo.secretario => Icons.assignment_ind_outlined,
      TipoCargo.haciendas => Icons.account_balance_wallet_outlined,
      TipoCargo.vocal => Icons.record_voice_over_outlined,
    };

/// Las dos consultas de la pantalla, pedidas juntas.
class _Datos {
  const _Datos(this.directorio, this.historial);

  final Directorio directorio;
  final List<Cargo> historial;

  static Future<_Datos> cargar(
      DirectorioRepository repo, Ambito ambito, int id) async {
    // En paralelo: son independientes y esperar una para pedir la otra
    // duplicaría el tiempo de carga sin motivo.
    final resultados = await Future.wait([
      repo.obtener(ambito, id),
      repo.historial(ambito, id),
    ]);
    return _Datos(resultados[0] as Directorio, resultados[1] as List<Cargo>);
  }
}

class _TarjetaCargo extends StatelessWidget {
  const _TarjetaCargo({
    required this.puesto,
    required this.ocupado,
    required this.alAsignar,
    required this.alTerminar,
    required this.alAbrirProductor,
    required this.alCambiarFirmas,
  });

  final Puesto puesto;
  final bool ocupado;
  final VoidCallback alAsignar;
  final VoidCallback alTerminar;
  final ValueChanged<int> alAbrirProductor;
  final VoidCallback alCambiarFirmas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final actual = puesto.actual;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _icono(puesto.cargo),
                  size: 20,
                  color: actual == null
                      ? tema.colorScheme.outline
                      : tema.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(puesto.etiqueta, style: tema.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            if (actual == null) ...[
              Text('Vacante',
                  style: tema.textTheme.bodyLarge?.copyWith(
                    color: tema.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  )),
              const SizedBox(height: 4),
              // Se dice acá que las firmas vienen después: si no, el usuario
              // las busca en esta pantalla y no las encuentra, porque una firma
              // sin firmante no tiene dónde ir. Y solo se promete donde las hay.
              Text(
                puesto.puedeFirmar
                    ? 'Asigná a alguien y después vas a poder cargar su firma y '
                        'su pie de firma.'
                    : 'Nadie ocupa este cargo.',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.outline),
              ),
            ] else ...[
              InkWell(
                onTap: () => alAbrirProductor(actual.productorId),
                child: Text(actual.productorNombre,
                    style: tema.textTheme.titleMedium),
              ),
              const SizedBox(height: 2),
              Text('En funciones ${actual.periodo}',
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.outline)),
              // Las firmas solo tienen sentido con alguien en el cargo, y solo
              // en los que firman: presidente y secretario. Al resto ni se le
              // ofrece, porque el backend las rechaza y ningún documento las usa.
              if (puesto.puedeFirmar) ...[
                const SizedBox(height: 16),
                FirmasCargo(cargo: actual, alCambiar: alCambiarFirmas),
              ],
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: ocupado ? null : alAsignar,
                  icon: Icon(
                      actual == null ? Icons.person_add_alt : Icons.swap_horiz,
                      size: 18),
                  label: Text(actual == null ? 'Asignar' : 'Cambiar'),
                ),
                if (actual != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Imprimir la credencial de dirigente',
                    onPressed: () =>
                        descargarCredencialDirigente(context, actual),
                    icon: const Icon(Icons.badge_outlined, size: 20),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: ocupado ? null : alTerminar,
                    child: Text('Dejar vacante',
                        style: TextStyle(color: tema.colorScheme.error)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Elegir a quién se le da el cargo, entre los candidatos del nivel.
class _SelectorProductor extends StatefulWidget {
  const _SelectorProductor({
    required this.puesto,
    required this.candidatos,
    required this.ambito,
  });

  final Puesto puesto;
  final List<Productor> candidatos;
  final Ambito ambito;

  @override
  State<_SelectorProductor> createState() => _SelectorProductorState();
}

class _SelectorProductorState extends State<_SelectorProductor> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final filtro = _busqueda.trim().toUpperCase();
    final visibles = filtro.isEmpty
        ? widget.candidatos
        : widget.candidatos
            .where((p) => p.nombreCompleto.toUpperCase().contains(filtro))
            .toList();

    final origen = switch (widget.ambito) {
      Ambito.sindicato => 'del sindicato',
      Ambito.central => 'de los sindicatos de la central',
      Ambito.federacion => 'de toda la federación',
    };

    return AlertDialog(
      title: Text('Elegir ${widget.puesto.etiqueta.toLowerCase()}'),
      content: SizedBox(
        width: 460,
        height: 480,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${widget.candidatos.length} disponibles $origen. '
                'Los que ya ocupan un cargo no aparecen.',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.outline),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: visibles.isEmpty
                  ? Center(
                      child: Text('Ninguno coincide.',
                          style: tema.textTheme.bodyMedium
                              ?.copyWith(color: tema.colorScheme.outline)),
                    )
                  : ListView.builder(
                      itemCount: visibles.length,
                      itemBuilder: (context, i) {
                        final p = visibles[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.person_outline, size: 20),
                          title: Text(p.nombreCompleto),
                          subtitle: Text([
                            if (p.ci != null) 'CI ${p.ci}',
                            p.sindicatoNombre,
                          ].join(' · ')),
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
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
      ],
    );
  }
}
