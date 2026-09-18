import 'dart:async';

import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../importacion/importacion_pagina.dart';
import '../padron_scope.dart';
import '../widgets/boton_tema.dart';
import '../widgets/estados.dart';
import '../widgets/lista_paginada.dart';
import 'fila_productor.dart';
import 'productor_detalle_pagina.dart';
import 'productor_formulario.dart';

/// Listado del padrón: búsqueda por texto, filtros en cascada y paginación.
class ProductoresPagina extends StatefulWidget {
  const ProductoresPagina({super.key});

  @override
  State<ProductoresPagina> createState() => _ProductoresPaginaState();
}

class _ProductoresPaginaState extends State<ProductoresPagina> {
  final TextEditingController _buscador = TextEditingController();
  final GlobalKey<ListaPaginadaState<Productor>> _lista = GlobalKey();

  Timer? _rebote;
  String _texto = '';
  Central? _central;
  Sindicato? _sindicato;
  OrdenProductores _orden = OrdenProductores.recientes;
  int? _productorSeleccionadoId;

  List<Central> _centrales = const [];
  List<Sindicato> _sindicatos = const [];
  bool _cargandoFiltros = true;

  @override
  void initState() {
    super.initState();
    _cargarCentrales();
  }

  @override
  void dispose() {
    _rebote?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargarCentrales() async {
    try {
      final centrales = await PadronScope.of(context).centrales.listar();
      if (!mounted) return;
      setState(() {
        _centrales = centrales;
        _cargandoFiltros = false;
      });
    } catch (_) {
      // Que fallen los filtros no debe impedir ver la lista: el error de la
      // lista ya se muestra en su propio sitio.
      if (mounted) setState(() => _cargandoFiltros = false);
    }
  }

  Future<void> _cargarSindicatos(Central? central) async {
    if (central == null) {
      setState(() {
        _sindicatos = const [];
        _sindicato = null;
      });
      return;
    }
    try {
      final sindicatos = await PadronScope.of(
        context,
      ).centrales.sindicatos(central.id);
      if (!mounted) return;
      setState(() {
        _sindicatos = sindicatos;
        _sindicato = null;
      });
    } catch (_) {
      if (mounted) setState(() => _sindicatos = const []);
    }
  }

  /// Espera a que el usuario deje de teclear antes de pedir al servidor.
  void _alEscribir(String valor) {
    _rebote?.cancel();
    _rebote = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _texto = valor.trim());
    });
  }

  /// Firma de los filtros: al cambiar, la lista se reinicia desde la página 0.
  String get _clave =>
      '$_texto|${_central?.id}|${_sindicato?.id}|${_orden.name}';

  @override
  Widget build(BuildContext context) {
    final padron = PadronScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productores'),
        actions: [
          const BotonTema(),
          IconButton(
            tooltip: 'Importar desde Excel',
            onPressed: _importar,
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton(
            tooltip: 'Recargar',
            onPressed: () => _lista.currentState?.refrescar(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo'),
      ),
      body: Column(
        children: [
          _barraFiltros(context),
          const Divider(height: 1),
          Expanded(
            child: ListaPaginada<Productor>(
              key: _lista,
              clave: _clave,
              cargar: (paginacion) => padron.productores.listar(
                texto: _texto.isEmpty ? null : _texto,
                centralId: _central?.id,
                sindicatoId: _sindicato?.id,
                orden: _orden,
                paginacion: paginacion,
              ),
              vacio: SinResultados(
                icono: Icons.person_search_outlined,
                mensaje: _hayFiltros
                    ? 'Ningún productor coincide con la búsqueda.'
                    : 'El padrón está vacío.',
                detalle: _hayFiltros
                    ? 'Probá quitando filtros o cambiando el texto.'
                    : 'Todavía no se cargó ningún productor.',
                accion: _hayFiltros
                    ? TextButton.icon(
                        onPressed: _limpiarFiltros,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Quitar filtros'),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: _importar,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Importar desde Excel'),
                      ),
              ),
              constructor: (context, p) => FilaProductor(
                productor: p,
                seleccionado: p.id == _productorSeleccionadoId,
                alTocar: () => _abrir(p),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _hayFiltros =>
      _texto.isNotEmpty || _central != null || _sindicato != null;

  void _limpiarFiltros() {
    _buscador.clear();
    setState(() {
      _texto = '';
      _central = null;
      _sindicato = null;
      _sindicatos = const [];
    });
  }

  Widget _barraFiltros(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final enFila = restricciones.maxWidth >= 860;

          final buscador = TextField(
            controller: _buscador,
            onChanged: _alEscribir,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, apellido, cédula o carné',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _buscador.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _buscador.clear();
                        setState(() => _texto = '');
                      },
                    ),
            ),
          );

          final filtroCentral = DropdownButtonFormField<Central?>(
            initialValue: _central,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Central'),
            items: [
              const DropdownMenuItem<Central?>(
                value: null,
                child: Text('Todas'),
              ),
              for (final c in _centrales)
                DropdownMenuItem<Central?>(value: c, child: Text(c.nombre)),
            ],
            onChanged: _cargandoFiltros
                ? null
                : (c) {
                    setState(() => _central = c);
                    _cargarSindicatos(c);
                  },
          );

          final filtroSindicato = DropdownButtonFormField<Sindicato?>(
            initialValue: _sindicato,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Sindicato',
              helperText: _central == null ? 'Elegí una central primero' : null,
            ),
            items: [
              const DropdownMenuItem<Sindicato?>(
                value: null,
                child: Text('Todos'),
              ),
              for (final s in _sindicatos)
                DropdownMenuItem<Sindicato?>(value: s, child: Text(s.nombre)),
            ],
            onChanged: _sindicatos.isEmpty
                ? null
                : (s) => setState(() => _sindicato = s),
          );

          final selectorOrden = DropdownButtonFormField<OrdenProductores>(
            initialValue: _orden,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ordenar por'),
            items: [
              for (final orden in OrdenProductores.values)
                DropdownMenuItem(value: orden, child: Text(orden.etiqueta)),
            ],
            onChanged: (orden) {
              if (orden != null) setState(() => _orden = orden);
            },
          );

          if (enFila) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: buscador),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: filtroCentral),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: filtroSindicato),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: selectorOrden),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: buscador),
              const SizedBox(width: 8),
              PopupMenuButton<OrdenProductores>(
                tooltip: 'Ordenar productores',
                initialValue: _orden,
                icon: const Icon(Icons.sort_by_alpha),
                onSelected: (orden) => setState(() => _orden = orden),
                itemBuilder: (context) => [
                  for (final orden in OrdenProductores.values)
                    PopupMenuItem(
                      value: orden,
                      child: Row(
                        children: [
                          Icon(
                            orden == _orden ? Icons.check : Icons.sort,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(orden.etiqueta)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _abrir(Productor p) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductorDetallePagina(productorId: p.id),
      ),
    );
    if (!mounted) return;
    setState(() => _productorSeleccionadoId = p.id);
    if (cambio == true) {
      await _lista.currentState?.refrescarConservandoPosicion();
    }
  }

  Future<void> _crear() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProductorFormulario()),
    );
    if (creado == true) _lista.currentState?.refrescar();
  }

  /// Una importación puede crear centrales y sindicatos además de productores,
  /// así que al volver se recargan también los filtros.
  Future<void> _importar() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ImportacionPagina()));
    if (!mounted) return;
    _lista.currentState?.refrescar();
    _cargarCentrales();
  }
}
