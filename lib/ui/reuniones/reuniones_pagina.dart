import 'dart:async';

import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import '../widgets/estados.dart';
import 'reunion_formulario.dart';
import 'reunion_pagina.dart';

/// Todas las reuniones, de la más reciente a la más antigua.
///
/// Con los años esta lista se hace larga —una asamblea por mes por sindicato ya
/// son cientos—, así que se entra por dos caminos en vez de bajar scrolleando:
/// las solapas por tipo, que es la división que la organización ya usa, y el
/// buscador, que además de mirar el detalle de la reunión mira a quién se vetó
/// en ella. «¿En qué reunión vetaron a Fulano?» es una pregunta que se hace
/// sola, y sin esto habría que abrir asamblea por asamblea.
class ReunionesPagina extends StatefulWidget {
  const ReunionesPagina({super.key});

  @override
  State<ReunionesPagina> createState() => _ReunionesPaginaState();
}

class _ReunionesPaginaState extends State<ReunionesPagina> {
  late Future<_Datos> _futuro;
  final _busqueda = TextEditingController();

  Timer? _espera;

  /// Null es «todas». El tipo elegido no entra en el conteo de las solapas.
  TipoReunion? _tipo;

  String _texto = '';

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  void _recargar() {
    final repo = PadronScope.of(context).reuniones;
    setState(() {
      _futuro = _Datos.cargar(repo, _tipo, _texto);
    });
  }

  /// Se busca sola mientras se escribe, pero no en cada tecla: con años de
  /// asambleas detrás, una consulta por letra sería una consulta por letra.
  void _alEscribir(String texto) {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || texto.trim() == _texto) return;
      _texto = texto.trim();
      _recargar();
    });
  }

  void _elegirTipo(TipoReunion? tipo) {
    if (_tipo == tipo) return;
    _tipo = tipo;
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reuniones'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: _recargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Convocar'),
      ),
      body: Column(
        children: [
          _buscador(context),
          Expanded(
            child: CargaAsync<_Datos>(
              futuro: _futuro,
              alReintentar: _recargar,
              constructor: _contenido,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buscador(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: TextField(
        controller: _busqueda,
        decoration: InputDecoration(
          hintText: 'Buscar por título, lugar, acta o por quién fue vetado',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _busqueda.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpiar',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _busqueda.clear();
                    _espera?.cancel();
                    _texto = '';
                    _recargar();
                  },
                ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) {
          // Redibuja para que aparezca la cruz de limpiar; la consulta espera.
          setState(() {});
          _alEscribir(v);
        },
      ),
    );
  }

  Widget _contenido(BuildContext context, _Datos datos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Solapas(
          conteo: datos.conteo,
          elegido: _tipo,
          alElegir: _elegirTipo,
        ),
        if (_texto.isNotEmpty && datos.reuniones.isNotEmpty)
          _AvisoDeBusqueda(cuantas: datos.reuniones.length, texto: _texto),
        Expanded(
          child: datos.reuniones.isEmpty
              ? _vacio(context, datos)
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: datos.reuniones.length,
                  itemBuilder: (context, i) => _Fila(
                    reunion: datos.reuniones[i],
                    alAbrir: () => _abrir(datos.reuniones[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _vacio(BuildContext context, _Datos datos) {
    if (_texto.isNotEmpty) {
      return SinResultados(
        icono: Icons.search_off,
        mensaje: 'Ninguna reunión coincide con «$_texto».',
        detalle: _tipo == null
            ? 'Se busca en el título, el lugar, las notas, el número del acta '
                'y en los vetos que se decidieron ahí.'
            : 'Probá en «Todas»: puede estar en otro tipo de reunión.',
        accion: TextButton(
          onPressed: () {
            _busqueda.clear();
            _espera?.cancel();
            _texto = '';
            _tipo = null;
            _recargar();
          },
          child: const Text('Limpiar la búsqueda'),
        ),
      );
    }
    if (_tipo != null) {
      return SinResultados(
        icono: iconoDeTipo(_tipo!),
        mensaje: 'Todavía no hay ${_tipo!.etiqueta.toLowerCase()}.',
        detalle: _tipo!.detalle,
        accion: TextButton(
          onPressed: () => _elegirTipo(null),
          child: const Text('Ver todas'),
        ),
      );
    }
    return SinResultados(
      icono: Icons.event_note_outlined,
      mensaje: 'Todavía no hay reuniones.',
      detalle: 'Convocá una y después pasá lista escaneando los carnets.',
      accion: FilledButton.icon(
        onPressed: _crear,
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Convocar reunión'),
      ),
    );
  }

  Future<void> _crear() async {
    final creada = await Navigator.of(context).push<Reunion>(
      MaterialPageRoute(builder: (_) => const ReunionFormulario()),
    );
    if (creada == null || !mounted) return;
    _recargar();
    _abrir(creada);
  }

  Future<void> _abrir(Reunion reunion) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReunionPagina(reunionId: reunion.id)),
    );
    if (mounted) _recargar();
  }
}

/// El listado y el conteo de las solapas, pedidos juntos.
class _Datos {
  const _Datos(this.reuniones, this.conteo);

  final List<Reunion> reuniones;
  final Map<TipoReunion, int> conteo;

  int get total => conteo.values.fold(0, (a, b) => a + b);

  static Future<_Datos> cargar(
      ReunionRepository repo, TipoReunion? tipo, String texto) async {
    final resultados = await Future.wait([
      repo.listar(tipo: tipo, texto: texto),
      repo.conteoPorTipo(texto: texto),
    ]);
    return _Datos(
      resultados[0] as List<Reunion>,
      resultados[1] as Map<TipoReunion, int>,
    );
  }
}

/// Una solapa por tipo, con cuántas hay en cada una.
///
/// Los tipos sin ninguna reunión se muestran igual, en cero: una solapa que
/// aparece y desaparece es más difícil de encontrar que una que dice cero.
class _Solapas extends StatelessWidget {
  const _Solapas({
    required this.conteo,
    required this.elegido,
    required this.alElegir,
  });

  final Map<TipoReunion, int> conteo;
  final TipoReunion? elegido;
  final ValueChanged<TipoReunion?> alElegir;

  @override
  Widget build(BuildContext context) {
    final total = conteo.values.fold(0, (a, b) => a + b);

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _Solapa(
            etiqueta: 'Todas',
            cuantas: total,
            icono: Icons.list_alt_outlined,
            elegida: elegido == null,
            alTocar: () => alElegir(null),
          ),
          for (final t in TipoReunion.values) ...[
            const SizedBox(width: 8),
            _Solapa(
              etiqueta: t.etiquetaCorta,
              cuantas: conteo[t] ?? 0,
              icono: iconoDeTipo(t),
              elegida: elegido == t,
              alTocar: () => alElegir(t),
            ),
          ],
        ],
      ),
    );
  }
}

class _Solapa extends StatelessWidget {
  const _Solapa({
    required this.etiqueta,
    required this.cuantas,
    required this.icono,
    required this.elegida,
    required this.alTocar,
  });

  final String etiqueta;
  final int cuantas;
  final IconData icono;
  final bool elegida;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icono, size: 18),
      label: Text('$etiqueta · $cuantas'),
      selected: elegida,
      onSelected: (_) => alTocar(),
    );
  }
}

/// Por qué salieron estas reuniones.
///
/// Buscando el apellido de alguien vetado, la reunión que aparece no lo
/// menciona en ninguna parte de su fila: sin esta línea, el resultado parece un
/// error. Decir dónde se buscó es más barato que marcar cada coincidencia, y
/// alcanza para entenderlo.
class _AvisoDeBusqueda extends StatelessWidget {
  const _AvisoDeBusqueda({required this.cuantas, required this.texto});

  final int cuantas;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        cuantas == 1
            ? '1 reunión coincide con «$texto», por su detalle o por un veto '
                'que se decidió ahí.'
            : '$cuantas reuniones coinciden con «$texto», por su detalle o por '
                'un veto que se decidió ahí.',
        style:
            tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.outline),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.reunion, required this.alAbrir});

  final Reunion reunion;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListTile(
      leading: Icon(iconoDeTipo(reunion.tipo),
          color: reunion.cerrada
              ? tema.colorScheme.outline
              : tema.colorScheme.primary),
      title: Text(reunion.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${reunion.tipo.etiqueta} · ${reunion.convocanteNombre}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(
            children: [
              Text(reunion.fechaCorta,
                  style: tema.textTheme.bodySmall
                      ?.copyWith(color: tema.colorScheme.outline)),
              if (reunion.codigoActa != null) ...[
                const SizedBox(width: 8),
                Text('Acta N° ${reunion.codigoActa}',
                    style: tema.textTheme.bodySmall
                        ?.copyWith(color: tema.colorScheme.outline)),
              ],
              if (reunion.vetosHabilitados) ...[
                const SizedBox(width: 8),
                Icon(Icons.gavel_outlined,
                    size: 13, color: tema.colorScheme.outline),
              ],
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${reunion.presentes} / ${reunion.convocados}',
              style: tema.textTheme.titleMedium),
          Text(reunion.cerrada ? 'Cerrada' : 'Abierta',
              style: tema.textTheme.labelSmall?.copyWith(
                color: reunion.cerrada
                    ? tema.colorScheme.outline
                    : tema.colorScheme.primary,
              )),
        ],
      ),
      onTap: alAbrir,
    );
  }
}

IconData iconoDeTipo(TipoReunion tipo) => switch (tipo) {
      TipoReunion.sindicato => Icons.groups_outlined,
      TipoReunion.ampliado => Icons.hub_outlined,
      TipoReunion.dirigentesCentral => Icons.groups_2_outlined,
      TipoReunion.dirigentesFederacion => Icons.account_balance_outlined,
    };
