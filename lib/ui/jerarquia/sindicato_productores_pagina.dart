import 'dart:async';

import 'package:flutter/material.dart';

import '../../repositories/padron.dart';
import '../credenciales/pliego_previa_pagina.dart';
import '../padron_scope.dart';
import '../productores/fila_productor.dart';
import '../productores/productor_detalle_pagina.dart';
import '../productores/productor_formulario.dart';
import '../widgets/descargas.dart';
import '../widgets/estados.dart';
import '../widgets/lista_paginada.dart';

/// Productores de un sindicato concreto.
///
/// Se llega desde la jerarquía, tocando el sindicato. Usa el mismo endpoint
/// paginado que el padrón completo, fijando el filtro `sindicatoId`.
class SindicatoProductoresPagina extends StatefulWidget {
  const SindicatoProductoresPagina({super.key, required this.sindicato});

  final Sindicato sindicato;

  @override
  State<SindicatoProductoresPagina> createState() =>
      _SindicatoProductoresPaginaState();
}

class _SindicatoProductoresPaginaState
    extends State<SindicatoProductoresPagina> {
  final GlobalKey<ListaPaginadaState<Productor>> _lista = GlobalKey();
  final TextEditingController _buscador = TextEditingController();
  Timer? _rebote;
  String _texto = '';
  OrdenProductores _orden = OrdenProductores.apellidos;

  @override
  void dispose() {
    _rebote?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  void _alEscribir(String valor) {
    _rebote?.cancel();
    _rebote = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _texto = valor.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final padron = PadronScope.of(context);
    final s = widget.sindicato;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'Central ${s.centralNombre} · '
              '${s.totalProductores ?? 0} '
              '${s.totalProductores == 1 ? 'productor' : 'productores'}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<OrdenProductores>(
            tooltip: 'Ordenar productores',
            initialValue: _orden,
            icon: const Icon(Icons.sort_by_alpha),
            onSelected: (orden) => setState(() => _orden = orden),
            itemBuilder: (context) => [
              for (final orden in OrdenProductores.values.where(
                (orden) => orden != OrdenProductores.recientes,
              ))
                PopupMenuItem(
                  value: orden,
                  child: Row(
                    children: [
                      Icon(
                        orden == _orden ? Icons.check : Icons.sort,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(orden.etiqueta),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Descargar la nómina en PDF, lista para imprimir',
            onPressed: () => descargarInformeSindicato(context, s),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: 'Estado e impresión de carnets',
            onPressed: _abrirImpresionMasiva,
            icon: const Icon(Icons.badge_outlined),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _buscador,
              onChanged: _alEscribir,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, apellido, cédula o carné',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _buscador.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _rebote?.cancel();
                          _buscador.clear();
                          setState(() => _texto = '');
                        },
                      ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListaPaginada<Productor>(
              key: _lista,
              clave: 'sindicato-${s.id}-${_orden.name}-$_texto',
              cargar: (paginacion) => padron.productores.listar(
                sindicatoId: s.id,
                texto: _texto.isEmpty ? null : _texto,
                orden: _orden,
                paginacion: paginacion,
              ),
              vacio: SinResultados(
                icono: Icons.person_search_outlined,
                mensaje: _texto.isEmpty
                    ? 'Este sindicato no tiene productores.'
                    : 'Ningún productor coincide con la búsqueda.',
                detalle: _texto.isEmpty
                    ? 'Registrá el primero: va a quedar asignado a «${s.nombre}» '
                          'sin que tengas que elegirlo.'
                    : 'Probá con otro nombre, apellido, cédula o código.',
                accion: _texto.isEmpty
                    ? FilledButton.icon(
                        onPressed: _crear,
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Registrar productor'),
                      )
                    : TextButton.icon(
                        onPressed: () {
                          _rebote?.cancel();
                          _buscador.clear();
                          setState(() => _texto = '');
                        },
                        icon: const Icon(Icons.search_off),
                        label: const Text('Quitar búsqueda'),
                      ),
              ),
              // La ruta se oculta: acá todas las filas pertenecen al mismo
              // sindicato, así que repetirla solo gasta espacio.
              constructor: (context, p) => FilaProductor(
                productor: p,
                mostrarRuta: false,
                alTocar: () => _abrir(p),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrir(Productor p) async {
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductorDetallePagina(productorId: p.id),
      ),
    );
    if (cambio == true) {
      await _lista.currentState?.refrescarConservandoPosicion();
    }
  }

  Future<void> _abrirImpresionMasiva() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PliegoPreviaPagina(sindicato: widget.sindicato),
      ),
    );
    if (mounted) {
      await _lista.currentState?.refrescarConservandoPosicion();
    }
  }

  /// Abre el alta con el sindicato ya puesto: es el sentido de tener el botón
  /// acá y no mandar al usuario a la sección Productores.
  Future<void> _crear() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductorFormulario(sindicatoFijo: widget.sindicato),
      ),
    );
    if (creado == true) _lista.currentState?.refrescar();
  }
}
