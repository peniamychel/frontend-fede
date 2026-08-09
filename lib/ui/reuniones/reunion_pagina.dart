import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../productores/productor_detalle_pagina.dart';
import '../widgets/estados.dart';
import 'escaner_qr.dart';
import 'reuniones_pagina.dart' show iconoDeTipo;

/// Pasar lista en una reunión.
///
/// La pantalla está pensada para usarse de pie, con el teléfono en una mano y
/// una fila de gente enfrente: la cámara arriba, el último resultado bien
/// grande, y la lista abajo para buscar a quien no tenga el carnet.
class ReunionPagina extends StatefulWidget {
  const ReunionPagina({super.key, required this.reunionId});

  final int reunionId;

  @override
  State<ReunionPagina> createState() => _ReunionPaginaState();
}

class _ReunionPaginaState extends State<ReunionPagina> {
  late Future<_Datos> _futuro;
  final _codigo = TextEditingController();

  /// Mientras se registra una lectura, la cámara no sigue leyendo.
  bool _registrando = false;

  /// El último resultado, para mostrarlo grande. Se limpia al recargar.
  RegistroAsistencia? _ultimo;
  String? _ultimoError;

  bool _soloAusentes = false;

  @override
  void initState() {
    super.initState();
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
      _futuro = _Datos.cargar(repo, widget.reunionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasar lista'),
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
    final reunion = datos.reunion;
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
                _Encabezado(reunion: reunion, alCambiarCierre: _cambiarCierre),
                const SizedBox(height: 16),
                if (reunion.cerrada)
                  _ListaCerrada(alReabrir: () => _cambiarCierre(false))
                else ...[
                  EscanerQr(pausado: _registrando, alLeer: _registrar),
                  const SizedBox(height: 12),
                  _entradaManual(),
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
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
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
                            cerrada: reunion.cerrada,
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
        Text('Lista', style: tema.textTheme.titleMedium),
        const SizedBox(width: 8),
        Text('${datos.reunion.presentes} de ${datos.reunion.convocados}',
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
          await PadronScope.of(context).reuniones.registrar(widget.reunionId, codigo);
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
        content: Text('${c.nombre} deja de figurar como presente.'),
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
      await PadronScope.of(context)
          .reuniones
          .quitar(widget.reunionId, c.productorId);
      if (mounted) _recargar();
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _cambiarCierre(bool cerrar) async {
    try {
      await PadronScope.of(context)
          .reuniones
          .cambiarCierre(widget.reunionId, cerrar);
      if (!mounted) return;
      mostrarExito(context, cerrar ? 'Lista cerrada.' : 'Lista reabierta.');
      _recargar();
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

/// Las dos consultas de la pantalla, pedidas juntas.
class _Datos {
  const _Datos(this.reunion, this.lista);

  final Reunion reunion;
  final List<Convocado> lista;

  static Future<_Datos> cargar(ReunionRepository repo, int id) async {
    final resultados = await Future.wait([repo.obtener(id), repo.lista(id)]);
    return _Datos(resultados[0] as Reunion, resultados[1] as List<Convocado>);
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.reunion, required this.alCambiarCierre});

  final Reunion reunion;
  final ValueChanged<bool> alCambiarCierre;

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
                Icon(iconoDeTipo(reunion.tipo), color: tema.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(reunion.titulo, style: tema.textTheme.titleLarge),
                ),
                IconButton(
                  tooltip: reunion.cerrada ? 'Reabrir la lista' : 'Cerrar la lista',
                  onPressed: () => alCambiarCierre(!reunion.cerrada),
                  icon: Icon(reunion.cerrada ? Icons.lock_open : Icons.lock_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${reunion.tipo.etiqueta} · ${reunion.convocanteNombre}',
                style: tema.textTheme.bodyMedium),
            Text(reunion.tipo.detalle,
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.outline)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _Dato(icono: Icons.event_outlined, texto: reunion.fechaCorta),
                if (reunion.lugar != null)
                  _Dato(icono: Icons.place_outlined, texto: reunion.lugar!),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: reunion.avance, minHeight: 8),
            const SizedBox(height: 6),
            Text(
              '${reunion.presentes} presentes · ${reunion.ausentes} faltan '
              'de ${reunion.convocados} convocados',
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 14, color: tema.colorScheme.outline),
        const SizedBox(width: 4),
        Text(texto, style: tema.textTheme.bodySmall),
      ],
    );
  }
}

class _ListaCerrada extends StatelessWidget {
  const _ListaCerrada({required this.alReabrir});

  final VoidCallback alReabrir;

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
                'La lista está cerrada: no admite más registros. La lista de '
                'abajo se puede seguir consultando.',
                style: tema.textTheme.bodyMedium,
              ),
            ),
            TextButton(onPressed: alReabrir, child: const Text('Reabrir')),
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
        convocado.presente
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
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
