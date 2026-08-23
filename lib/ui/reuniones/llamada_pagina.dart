import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/productor_detalle_pagina.dart';
import '../widgets/estados.dart';
import 'escaner_qr.dart';

/// Pasar lista en una vuelta.
///
/// La pantalla está pensada para usarse de pie, con el teléfono en una mano y
/// una fila de gente enfrente: la cámara arriba, el último resultado bien
/// grande, y la lista abajo para buscar a quien no tenga el carnet.
///
/// Es una vuelta y no la reunión entera: en una asamblea se llama lista varias
/// veces, y quien llegó a la tercera no tiene por qué figurar en la primera.
class LlamadaPagina extends StatefulWidget {
  const LlamadaPagina({
    super.key,
    required this.llamada,
    required this.tituloReunion,
  });

  final LlamadaLista llamada;
  final String tituloReunion;

  @override
  State<LlamadaPagina> createState() => _LlamadaPaginaState();
}

class _LlamadaPaginaState extends State<LlamadaPagina> {
  late Future<_Datos> _futuro;
  final _codigo = TextEditingController();

  /// La vuelta puede cerrarse desde acá, así que su estado no sale de
  /// `widget.llamada`, que quedó fijo al entrar.
  late LlamadaLista _llamada;

  /// Mientras se registra una lectura, la cámara no sigue leyendo.
  bool _registrando = false;

  /// El último resultado, para mostrarlo grande. Se limpia al recargar.
  RegistroAsistencia? _ultimo;
  String? _ultimoError;

  bool _soloAusentes = false;

  @override
  void initState() {
    super.initState();
    _llamada = widget.llamada;
    _recargar();
  }

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  void _recargar() {
    final repo = PadronScope.of(context).reuniones;
    setState(() {
      _futuro = _Datos.cargar(repo, _llamada.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_llamada.etiqueta),
        // El título de la reunión abajo: sin él, tres vueltas de tres
        // asambleas distintas se ven todas iguales.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.tituloReunion,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
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
        constructor: (context, datos) => _contenido(context, datos),
      ),
    );
  }

  Widget _contenido(BuildContext context, _Datos datos) {
    final visibles = _soloAusentes
        ? datos.lista.where((c) => !c.presente).toList()
        : datos.lista;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Marcador(
                  presentes: datos.presentes,
                  convocados: datos.lista.length,
                  abierta: _llamada.abierta,
                  nota: _llamada.nota,
                ),
                const SizedBox(height: 16),
                if (!_llamada.abierta)
                  _VueltaCerrada(hora: _llamada.horaCierre)
                else ...[
                  EscanerQr(pausado: _registrando, alLeer: _registrar),
                  const SizedBox(height: 12),
                  _entradaManual(),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _cerrarVuelta,
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: const Text('Cerrar esta llamada'),
                    ),
                  ),
                ],
                if (_ultimo != null || _ultimoError != null) ...[
                  const SizedBox(height: 12),
                  _Resultado(registro: _ultimo, error: _ultimoError),
                ],
                const SizedBox(height: 24),
                _cabeceraLista(context, datos),
                const SizedBox(height: 4),
                if (visibles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _soloAusentes
                          ? 'No falta nadie.'
                          : 'Esta reunión no convoca a nadie todavía.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final c in visibles)
                          _FilaConvocado(
                            convocado: c,
                            cerrada: !_llamada.abierta,
                            alQuitar: () => _quitar(c),
                            alAbrir: () => _abrirProductor(c.productorId),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _entradaManual() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _codigo,
            textCapitalization: TextCapitalization.characters,
            enabled: !_registrando,
            decoration: const InputDecoration(
              labelText: 'Código de la credencial',
              helperText: 'Está impreso debajo del QR',
              prefixIcon: Icon(Icons.keyboard_outlined),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _registrarEscrito(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _registrando ? null : _registrarEscrito,
          child: const Text('Registrar'),
        ),
      ],
    );
  }

  Widget _cabeceraLista(BuildContext context, _Datos datos) {
    final tema = Theme.of(context);
    return Row(
      children: [
        Text('Afiliados', style: tema.textTheme.titleMedium),
        const SizedBox(width: 8),
        Text('${datos.presentes} de ${datos.lista.length}',
            style: tema.textTheme.bodySmall
                ?.copyWith(color: tema.colorScheme.outline)),
        const Spacer(),
        FilterChip(
          label: const Text('Solo los que faltan'),
          selected: _soloAusentes,
          onSelected: (v) => setState(() => _soloAusentes = v),
        ),
      ],
    );
  }

  // ---------- Acciones ----------

  void _registrarEscrito() {
    final codigo = _codigo.text.trim();
    if (codigo.isEmpty) return;
    _registrar(codigo);
  }

  Future<void> _registrar(String codigo) async {
    if (_registrando) return;
    setState(() {
      _registrando = true;
      _ultimoError = null;
    });

    try {
      final registro =
          await PadronScope.of(context).reuniones.registrar(_llamada.id, codigo);
      if (!mounted) return;
      _codigo.clear();
      setState(() {
        _ultimo = registro;
        _registrando = false;
      });
      _recargar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ultimo = null;
        // El mensaje va a la tarjeta grande y no a un aviso que se desvanece:
        // quien está pasando lista necesita poder leerlo mientras le explica
        // a la persona que tiene enfrente por qué no entró.
        _ultimoError = e is ApiException ? e.mensaje : '$e';
        _registrando = false;
      });
    }
  }

  Future<void> _quitar(Convocado c) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Quitar de la lista?'),
        content: Text('${c.nombre} deja de figurar como presente en '
            '${_llamada.etiqueta.toLowerCase()}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      await PadronScope.of(context).reuniones.quitar(_llamada.id, c.productorId);
      if (!mounted) return;
      _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _cerrarVuelta() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Cerrar ${_llamada.etiqueta.toLowerCase()}?'),
        content: const Text(
          'No admite más registros. Si después hay que anotar a alguien más, '
          'se abre otra llamada desde la reunión.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    try {
      final cerrada =
          await PadronScope.of(context).reuniones.cerrarLlamada(_llamada.id);
      if (!mounted) return;
      setState(() {
        _llamada = cerrada;
      });
      mostrarExito(context, '${cerrada.etiqueta} cerrada.');
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _abrirProductor(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductorDetallePagina(productorId: id)),
    );
    if (mounted) _recargar();
  }

}

/// La lista de esa vuelta.
class _Datos {
  const _Datos(this.lista);

  final List<Convocado> lista;

  int get presentes => lista.where((c) => c.presente).length;

  static Future<_Datos> cargar(ReunionRepository repo, int llamadaId) async {
    return _Datos(await repo.lista(llamadaId));
  }
}

/// Cuántos van, bien grande. Es lo que se mira sin bajar la vista al teléfono.
class _Marcador extends StatelessWidget {
  const _Marcador({
    required this.presentes,
    required this.convocados,
    required this.abierta,
    required this.nota,
  });

  final int presentes;
  final int convocados;
  final bool abierta;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final avance = convocados == 0 ? 0.0 : presentes / convocados;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$presentes', style: tema.textTheme.displaySmall),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('de $convocados convocados',
                      style: tema.textTheme.bodyMedium),
                ),
                const Spacer(),
                Chip(
                  avatar: Icon(
                    abierta ? Icons.podcasts : Icons.lock_outline,
                    size: 16,
                  ),
                  label: Text(abierta ? 'Abierta' : 'Cerrada'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: avance, minHeight: 8),
            if (nota != null) ...[
              const SizedBox(height: 10),
              Text(nota!,
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.outline)),
            ],
          ],
        ),
      ),
    );
  }
}

class _VueltaCerrada extends StatelessWidget {
  const _VueltaCerrada({required this.hora});

  final String? hora;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      color: tema.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: tema.colorScheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hora == null
                    ? 'Esta llamada está cerrada: no admite más registros.'
                    : 'Esta llamada se cerró a las $hora. Para anotar a alguien '
                        'más, se abre otra desde la reunión.',
                style: tema.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El último resultado, bien grande y con color.
///
/// Es lo que se mira sin bajar la vista al teléfono, así que el color hace más
/// trabajo que el texto: verde entró, ámbar ya estaba, rojo no corresponde.
class _Resultado extends StatelessWidget {
  const _Resultado({required this.registro, required this.error});

  final RegistroAsistencia? registro;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esError = error != null;
    final repetido = registro?.repetido ?? false;

    final (Color fondo, Color frente, IconData icono) = esError
        ? (tema.colorScheme.errorContainer, tema.colorScheme.onErrorContainer,
            Icons.block)
        : repetido
            ? (const Color(0xFFFFF0C2), const Color(0xFF6B4E00),
                Icons.info_outline)
            : (const Color(0xFFD7F0DC), const Color(0xFF14532D),
                Icons.check_circle_outline);

    return Card(
      color: fondo,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icono, color: frente, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esError ? error! : registro!.persona.nombre,
                    style: tema.textTheme.titleMedium?.copyWith(color: frente),
                  ),
                  if (!esError) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        repetido ? 'Ya estaba registrado' : 'Registrado',
                        registro!.persona.sindicato,
                        if (registro!.persona.cargo != null)
                          registro!.persona.cargo!,
                      ].join(' · '),
                      style: tema.textTheme.bodySmall?.copyWith(color: frente),
                    ),
                  ],
                ],
              ),
            ),
            if (!esError)
              Text('${registro!.presentes}',
                  style: tema.textTheme.headlineSmall?.copyWith(color: frente)),
          ],
        ),
      ),
    );
  }
}

class _FilaConvocado extends StatelessWidget {
  const _FilaConvocado({
    required this.convocado,
    required this.cerrada,
    required this.alQuitar,
    required this.alAbrir,
  });

  final Convocado convocado;
  final bool cerrada;
  final VoidCallback alQuitar;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListTile(
      dense: true,
      leading: Icon(
        convocado.presente ? Icons.check_circle : Icons.radio_button_unchecked,
        color: convocado.presente
            ? const Color(0xFF2E7D32)
            : tema.colorScheme.outlineVariant,
      ),
      title: Text(convocado.nombre,
          style: TextStyle(
            color: convocado.presente ? null : tema.colorScheme.outline,
          )),
      subtitle: Text(
        [
          convocado.cargo ?? convocado.sindicato,
          if (convocado.ci != null) 'CI ${convocado.ci}',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: convocado.presente
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (convocado.horaLlegada != null)
                  Text(convocado.horaLlegada!,
                      style: tema.textTheme.bodySmall
                          ?.copyWith(color: tema.colorScheme.outline)),
                if (!cerrada)
                  IconButton(
                    tooltip: 'Quitar de la lista',
                    onPressed: alQuitar,
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            )
          : null,
      onTap: alAbrir,
    );
  }
}
