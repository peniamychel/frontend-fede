import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import 'llamada_pagina.dart';
import 'reuniones_pagina.dart' show iconoDeTipo;
import 'tarjeta_acta.dart';
import 'tarjeta_vetos.dart';

/// Una reunión, en cuadros.
///
/// Cada cuadro es una cosa que se hace en la asamblea y se hace por separado:
/// quién convoca y cuándo, llamar lista, subir el acta, y —si toca— los vetos.
/// Antes estaba todo en una sola pantalla larga, con el acta y las decisiones
/// enredadas en el pase de lista, que son momentos distintos de la reunión.
class ReunionPagina extends StatefulWidget {
  const ReunionPagina({super.key, required this.reunionId});

  final int reunionId;

  @override
  State<ReunionPagina> createState() => _ReunionPaginaState();
}

class _ReunionPaginaState extends State<ReunionPagina> {
  late Future<_Datos> _futuro;

  @override
  void initState() {
    super.initState();
    _recargar();
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
        title: const Text('Reunión'),
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TarjetaEncabezado(reunion: datos.reunion),
                    const SizedBox(height: 16),
                    _TarjetaLlamadas(
                      reunion: datos.reunion,
                      llamadas: datos.llamadas,
                      alAbrir: _abrirLlamada,
                      alEntrar: _entrarALlamada,
                      alCambiarCierre: _cambiarCierre,
                    ),
                    const SizedBox(height: 16),
                    TarjetaActa(reunion: datos.reunion, alCambiar: _recargar),
                    const SizedBox(height: 16),
                    TarjetaVetos(reunion: datos.reunion, alCambiar: _recargar),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Acciones ----------

  Future<void> _abrirLlamada() async {
    final nota = await showDialog<String?>(
      context: context,
      builder: (context) => const _DialogoNuevaLlamada(),
    );
    // El diálogo devuelve null si se canceló, y cadena vacía si se aceptó sin
    // escribir nota: son cosas distintas.
    if (nota == null || !mounted) return;

    try {
      final llamada = await PadronScope.of(context)
          .reuniones
          .abrirLlamada(widget.reunionId, nota: nota.isEmpty ? null : nota);
      if (!mounted) return;
      _recargar();
      await _entrarALlamada(llamada);
    } catch (e) {
      if (mounted) mostrarError(context, e);
    }
  }

  Future<void> _entrarALlamada(LlamadaLista llamada) async {
    final datos = await _futuro;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LlamadaPagina(
          llamada: llamada,
          tituloReunion: datos.reunion.titulo,
        ),
      ),
    );
    if (mounted) _recargar();
  }

  Future<void> _cambiarCierre(bool cerrar) async {
    if (cerrar) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Cerrar la lista?'),
          content: const Text(
            'No se van a poder abrir más llamadas, y la que esté abierta se '
            'cierra. Lo ya registrado se sigue viendo.',
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
    }

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
}

/// Lo que muestra la pantalla, pedido junto.
class _Datos {
  const _Datos(this.reunion, this.llamadas);

  final Reunion reunion;
  final List<LlamadaLista> llamadas;

  static Future<_Datos> cargar(ReunionRepository repo, int id) async {
    final resultados =
        await Future.wait([repo.obtener(id), repo.llamadas(id)]);
    return _Datos(
        resultados[0] as Reunion, resultados[1] as List<LlamadaLista>);
  }
}

// --------------------------------------------------- el cuadro de arriba

class _TarjetaEncabezado extends StatelessWidget {
  const _TarjetaEncabezado({required this.reunion});

  final Reunion reunion;

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
            if (reunion.observaciones != null) ...[
              const SizedBox(height: 8),
              Text(reunion.observaciones!, style: tema.textTheme.bodySmall),
            ],
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

// ------------------------------------------------- el cuadro de la lista

/// Resumen de las vueltas de lista, con la opción de abrir otra o cerrar.
///
/// Se entra a cada vuelta para ver a los afiliados: acá solo va el resumen,
/// porque tres listas de doscientos nombres una debajo de otra no se leen.
class _TarjetaLlamadas extends StatelessWidget {
  const _TarjetaLlamadas({
    required this.reunion,
    required this.llamadas,
    required this.alAbrir,
    required this.alEntrar,
    required this.alCambiarCierre,
  });

  final Reunion reunion;
  final List<LlamadaLista> llamadas;
  final VoidCallback alAbrir;
  final ValueChanged<LlamadaLista> alEntrar;
  final ValueChanged<bool> alCambiarCierre;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final hayAbierta = llamadas.any((l) => l.abierta);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.how_to_reg_outlined, color: tema.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Llamar lista', style: tema.textTheme.titleLarge),
                ),
                if (reunion.cerrada)
                  Chip(
                    avatar: const Icon(Icons.lock_outline, size: 16),
                    label: const Text('Cerrada'),
                    backgroundColor: tema.colorScheme.surfaceContainerHighest,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Se puede llamar lista varias veces en la misma reunión: al '
              'empezar, más tarde para los que llegaron con retraso, y al '
              'final.',
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.outline),
            ),
            const SizedBox(height: 12),
            _resumen(context),
            const SizedBox(height: 12),
            if (llamadas.isEmpty)
              Text(
                reunion.cerrada
                    ? 'La lista se cerró sin haber llamado ninguna vez.'
                    : 'Todavía no se llamó lista.',
                style: tema.textTheme.bodyMedium,
              )
            else
              Column(
                children: [
                  for (final l in llamadas)
                    _FilaLlamada(llamada: l, alEntrar: () => alEntrar(l)),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!reunion.cerrada)
                  FilledButton.tonalIcon(
                    onPressed: alAbrir,
                    icon: const Icon(Icons.add),
                    label: Text(
                        llamadas.isEmpty ? 'Llamar lista' : 'Otra llamada'),
                  ),
                if (hayAbierta) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Hay una llamada abierta. Cerrala antes de abrir otra.',
                      style: tema.textTheme.bodySmall
                          ?.copyWith(color: tema.colorScheme.outline),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: () => alCambiarCierre(!reunion.cerrada),
                  icon: Icon(
                      reunion.cerrada ? Icons.lock_open : Icons.lock_outline,
                      size: 18),
                  label: Text(reunion.cerrada ? 'Reabrir' : 'Cerrar lista'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Cuántos estuvieron en la reunión, contando a cada uno una sola vez aunque
  /// haya venido a tres vueltas.
  Widget _resumen(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: reunion.avance, minHeight: 8),
        const SizedBox(height: 6),
        Text(
          '${reunion.presentes} estuvieron · ${reunion.ausentes} faltaron '
          'de ${reunion.convocados} convocados',
          style: tema.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _FilaLlamada extends StatelessWidget {
  const _FilaLlamada({required this.llamada, required this.alEntrar});

  final LlamadaLista llamada;
  final VoidCallback alEntrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final abierta = llamada.abierta;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        abierta ? Icons.podcasts : Icons.playlist_add_check,
        color: abierta ? tema.colorScheme.primary : tema.colorScheme.outline,
      ),
      title: Text(llamada.etiqueta),
      subtitle: Text(
        [
          '${llamada.presentes} presentes',
          if (abierta)
            'en curso'
          else if (llamada.horaCierre != null)
            'cerrada ${llamada.horaCierre}'
          else
            'cerrada',
          if (llamada.nota != null) llamada.nota!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: alEntrar,
    );
  }
}

/// Pregunta la nota antes de abrir la vuelta.
///
/// Es opcional a propósito: en la primera no hay nada que aclarar, pero en la
/// tercera "después del cuarto intermedio" es lo que le da sentido a que haya
/// treinta presentes en vez de ciento veinte.
class _DialogoNuevaLlamada extends StatefulWidget {
  const _DialogoNuevaLlamada();

  @override
  State<_DialogoNuevaLlamada> createState() => _DialogoNuevaLlamadaState();
}

class _DialogoNuevaLlamadaState extends State<_DialogoNuevaLlamada> {
  final _nota = TextEditingController();

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Llamar lista'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Se abre una vuelta nueva. Lo que se registre a partir de ahora va '
            'a esta.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nota,
            autofocus: true,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Nota (opcional)',
              hintText: 'Después del cuarto intermedio',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_nota.text.trim()),
          child: const Text('Abrir'),
        ),
      ],
    );
  }
}
